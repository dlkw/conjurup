import ceylon.collection {
    HashMap,
    ArrayList,
    MutableList,
    MutableMap
}
import ceylon.io.charset {
    utf8
}
import ceylon.json {
    JsonValue=Value,
    JsonObject=Object,
    JsonArray=Array,
    jsonParse=parse
}
import ceylon.language.meta {
    type,
    annotations
}
import ceylon.language.meta.declaration {
    FunctionDeclaration,
    ValueDeclaration
}
import ceylon.language.meta.model {
    Function,
    Interface,
    Type
}
import ceylon.logging {
    Logger,
    logger,
    trace
}
import ceylon.net.http {
    HttpMethod=Method,
    contentTypeFormUrlEncoded,
    Header
}
import ceylon.net.http.server {
    Server,
    newServer,
    Request,
    Response,
    TemplateEndpoint
}
import ceylon.time {
    Date
}

import de.dlkw.conjurup {
    BodyParameterStuff
}
import de.dlkw.conjurup.annotations {
    ResourceAccessAnnotation,
    PathAnnotation,
    ParamAnnotation,
    ConsumesAnnotation
}
import de.dlkw.conjurup.swagger {
    PathItem,
    mkSwagger=swagger,
    Path,
    Parameter,
    PIT,
    BP,
    ParameterLocation
}

Logger log = logger(`package de.dlkw.conjurup`);

shared class PathAndMethodClashException([String+] messages)
    extends Exception()
{
    String calcMessageString()
    {
        if (messages.shorterThan(2)) {
            return messages.first;
        }
        variable String msg = "The following clashes have been found:";
        for (m in messages) {
            msg = msg + "\n\t" + m;
        }
        return msg;
    }
    shared actual String message = calcMessageString();
}

shared class RESTServer()
{
    log.priority = trace;
    Server httpServer = newServer({});

    value contentTypeHandlers = HashMap<String, ContentTypeHandler<Object?>>();
    shared void registerContentTypeHandler(ContentTypeHandler<Object?> contentTypeHandler)
    {
        contentTypeHandlers.put(contentTypeHandler.contentType, contentTypeHandler);
    }
    registerContentTypeHandler(jsonObjectEntityConverter);


    // make overridable/configurable
    ResponseConverter responseConverter = stdResponseConverter;

    value pathMap = HashMap<String, MutableMap<HttpMethod, FunctionStuff>>();
    value functionMapX = HashMap<Anything(Nothing), HashMap<String, MutableList<HttpMethod>>>();
    // not thread safe!

    void assertAllAbsent(Map<String, Map<HttpMethod, FunctionStuff>> newValues,
            Map<String, Map<HttpMethod, FunctionStuff>> store)
    {
        variable String[] errs = [];
        for (path -> newMethodMap in newValues) {
            if (exists storedMethodMap = store.get(path)) {
                for (newMethod -> newFunction in newMethodMap) {
                    for (storedMethod -> storedFunction in storedMethodMap) {
                        if (newMethod == storedMethod) {
                            errs = errs.withTrailing("Duplicate ``newMethod`` ``path`` for ``newFunction.functionName`` clashes with ``storedFunction.functionName``.");
                            break;
                        }
                    }
                }
            }
        }
        if (nonempty e = errs) {
            throw PathAndMethodClashException(e);
        }
    }

    void assertAbsentThenPut(Map<String, Map<HttpMethod, FunctionStuff>> newValues,
            MutableMap<String, MutableMap<HttpMethod, FunctionStuff>> store)
    {
        assertAllAbsent(newValues, store);

        for (path -> newMethodMap in newValues) {
            MutableMap<HttpMethod, FunctionStuff> storedMethodMap;
            if (exists sMM = store.get(path)) {
                storedMethodMap = sMM;
            }
            else {
                storedMethodMap = HashMap<HttpMethod, FunctionStuff>();
                store.put(path, storedMethodMap);
            }

            for (method -> functionStuff in newMethodMap) {
                storedMethodMap.put(method, functionStuff);
            }
        }
    }

    void summarize()
    {
        for (p->mm in pathMap) {
            for (m->f in mm) {
                log.info("``m`` ``p``: ``f.functionName``");
            }
        }
    }

	shared JsonObject swagger(
		"The title of the application."
        String title,

	    "The version of the API."
	    String version,

	    "A description of the application."
	    String? description = null)
	{
		value pM = HashMap<String, ArrayList<PathItem>>();

		PIT mkPit(SimpleParameterStuff ps)
		{
			String type;
			if (ps.type == `String`) {
				type = "string";
			}
			else if (ps.type == `Integer`) {
				type = "integer";
			}
			else if (ps.type == `Boolean`) {
				type = "boolean";
			}
			else {
				throw AssertionError("unhandled parameter type ``ps.type``");
			}

			PIT pit = PIT(type, "", null);
			return pit;
		}
		Parameter mkP(SimpleParameterStuff ps)
		{
			String type;
			String? format;
			PIT? pit;
			if (ps.isMulti) {
				type = "array";
				format = null;
				pit = mkPit(ps);
			}
			else {
				pit = null;
				if (ps.type == `String`) {
					type = "string";
					format = null;
				}
				else if (ps.type == `Integer`) {
					type = "integer";
					format = null;
				}
				else if (ps.type == `Float`) {
					type = "number";
					format = null;
				}
				else if (ps.type == `Boolean`) {
					type = "boolean";
					format = null;
				}
				// FIXME do it right
				else if (ps.type == `Date`) {
					type = "string";
					format = "date";
				}
				else {
					throw AssertionError("unhandled parameter type ``ps.type``");
				}
			}

			ParameterLocation location;
			switch (ps.source)
			case (query) {
				location = ParameterLocation.query;
			}
			case (path) {
				location = ParameterLocation.path;
			}
			case (header) {
				location = ParameterLocation.header;
			}
			case (form) {
				location = ParameterLocation.formData;
			}
			else {
				throw AssertionError("unsupported parameter location ``ps.source``");
			}

			Parameter p = Parameter(ps.name,
				location,
				null, type, format, true, pit, !ps.nullAllowed);
			return p;
		}

		PathItem mkME(HttpMethod method, FunctionStuff fs)
		{
			variable Parameter[] pp = [];
			variable BP? bp = null;
			for (ps in fs.parameters) {
				Parameter p;
				if (is SimpleParameterStuff ps) {
					p = mkP(ps);
					pp = pp.withTrailing(p);
				}
				else {
					// TODO need to get type from input class (object, array, string, etc.)
					JsonObject schema = JsonObject {
						"type" -> JsonArray {
							"object", "array", "string", "number", "boolean", "null"
						}
					};
					bp = BP(ps.name, schema, false);
				}
			}
			PathItem me = PathItem(method, [fs.consumes], pp, bp, fs.response.type);
			return me;
		}

		for (p -> mm in pathMap) {
			for (m->ifs in mm) {
    			ArrayList<PathItem> ls;
    			ArrayList<PathItem>? mes = pM[p];
    			if (is Null mes) {
    				ls = ArrayList<PathItem>();
    				pM.put(p, ls);
    			}
    			else {
    				ls = mes;
    			}
    			ls.add(mkME(m, ifs));
            }
		}

		value eps = pM.map((a) => Path("/"+a.key, a.item.sequence()));

		value swaggerJ = mkSwagger(title, version, eps, description);
		return swaggerJ;
	}

    "Starts this server in the current thread. This method will not return before the server is stopped."
    shared void start()
    {
        for (path->methodMap in pathMap) {
            TemplateEndpoint endpoint = TemplateEndpoint {
                pathTemplate => path;
                acceptMethod => methodMap.keys;
                service => (Request rq, Response rp)
                {
                    if (exists functionStuff = methodMap.get(rq.method)) {
                        functionStuff.service(rq, rp);
                    }
                    else {
                        rp.responseStatus = 405;
                    }
                };
            };
            httpServer.addEndpoint(endpoint);
        }

        summarize();
        log.info(swagger("The glorious title of this incredible application", "1.0.0", "This example should illustrate a bit setting up a RESTful API and generating its Swagger description.").string);
        httpServer.start();
    }

	// not thread safe!
    shared void addEndpoint(path, method, annotatedFunction)
    {
        String path;
        HttpMethod method;
        Function<Anything, Nothing> annotatedFunction;

        String canonicalizedPath = canonicalizePathComponent(path);

        value functionStuff = doAddEndpoint(canonicalizedPath, annotatedFunction);

		assertAbsentThenPut(map({canonicalizedPath -> map({method -> functionStuff})}), pathMap);
    }

    FunctionStuff doAddEndpoint(path, annotatedFunction)
    {
        String path;
        Function<Anything, Nothing> annotatedFunction;

        value [consumes, argumentCreators, response] = buildArgumentCreators(annotatedFunction, path);

        value service = (Request rq, Response rp)
        {
            try {
                log.debug("called endpoint ``rq.relativePath``");

                RequestAnalyzer requestAnalyzer;
                try {
                    requestAnalyzer = RequestAnalyzer(rq, consumes);
                }
                catch (Exception e) {
                    log.debug("Content-Type mismatch");
                    rp.addHeader(Header("Content-Type", "text/plain"));
                    rp.responseStatus = 415;
                    rp.writeByteBuffer(utf8.encode(e.message));
                    return;
                }

                value convertedRequestParms = argumentCreators
                        .map((p) => p.argumentCreator)
                        .collect((Anything(RequestAnalyzer) el) => el(requestAnalyzer));
                variable Anything[] args = [];
                variable <NamedConversionError|BodyNoConverterError|BodyConversionError>[] errors = [];
                log.debug("converted request parameters are: ``convertedRequestParms``");
                for (x in convertedRequestParms) {
                    if (is NamedConversionError x) {
                        errors = errors.withTrailing(x);
                    }
                    if (is BodyNoConverterError x) {
                        errors = errors.withTrailing(x);
                    }
                    if (is BodyConversionError x) {
                        errors = errors.withTrailing(x);
                    }
                    else {
                        value t = type(x);
                        log.debug("> ``x else "null"`` of type ``t``");
                        args = args.withTrailing(x);
                    }
                }
                if (errors.empty) {
                    log.debug("dispatching to ``annotatedFunction`` using arguments ``convertedRequestParms``");
                    value result = annotatedFunction.apply(*args);
                    log.debug(if (exists result) then "result was ``result``" else "no result (null or void)");
                    if (is JsonValue result) {
                        rp.addHeader(Header("Content-Type", "application/json"));
                        rp.writeByteBuffer(responseConverter.convertResultToByte(result));
                    }
                }
                else {
                    log.debug("conversion errors! ``errors``");
                    rp.addHeader(Header("Content-Type", responseConverter.contentType));
                    rp.responseStatus = 400;
                    rp.writeByteBuffer(responseConverter.convertArgumentConversionErrorToByte(errors));
	            }
            }
            catch (Throwable e) {
                log.error("fixme: implement proper exception handling", e);
            }
        };

        value functionStuff = FunctionStuff(annotatedFunction.string, consumes, argumentCreators, service, response);

		return functionStuff;
    }

    shared void addResourceAccessor(Object obj)
    {
        value scanInfo = scanObject(obj);

        value endpointsMap = HashMap<String, MutableMap<HttpMethod, FunctionStuff>>();
        for (path -> httpMethodEntries in scanInfo) {
            value httpMethodEntries2 = HashMap<HttpMethod, FunctionStuff>();
            endpointsMap.put(path, httpMethodEntries2);
            for (method -> fun in httpMethodEntries) {
                value functionStuff = doAddEndpoint(path, fun);
                httpMethodEntries2.put(method, functionStuff);
            }
        }
        assertAbsentThenPut(endpointsMap, pathMap);
    }

    "Scans an object for annotations to use (some of) its methods as REST resource accessors."
    Map<String, Map<HttpMethod, Function<Object, Nothing>>> scanObject(Object resource)
    {
        value classModel = type(resource);
        value classDeclaration = classModel.declaration;

        log.debug("scanning an instance of ``classModel`` for resource accessors");

        PathAnnotation[] pathAnnotations = classDeclaration.annotations<PathAnnotation>();
        if (nonempty pathAnnotations) {
            // cannot have more than one (satisfies OptionalAnnotation)
            PathAnnotation pathAnnotation = pathAnnotations.first;

            // the root path that will be prepended to all endpoints in this object
            String rootPath = canonicalizePathComponent(pathAnnotation.ppath);
            log.debug("root path ``rootPath`` for ``classModel``");

            value resultMap = HashMap<String, MutableMap<HttpMethod, Function<Object, Nothing>>>();

            value annotatedMethods = classModel.getDeclaredMethods<Nothing, Object, Nothing>(`ResourceAccessAnnotation`);
            if (!nonempty annotatedMethods) {
                throw Exception("no method annotated resourceAccessor found in ``classModel``");
            }

            for (method in annotatedMethods) {
                value functionDeclaration = method.declaration;
                value pathAndMethod = pathForAccessor(functionDeclaration, rootPath);
                value boundMethod = method.bind(resource);

                MutableMap<HttpMethod, Function<Object, Nothing>> httpMethodEntries;
                if (exists hME = resultMap.get(pathAndMethod.path)) {
                    httpMethodEntries = hME;
                }
                else {
                    httpMethodEntries = HashMap<HttpMethod, Function<Object, Nothing>>();
                    resultMap.put(pathAndMethod.path, httpMethodEntries);
                }
                if (exists fun = httpMethodEntries.put(pathAndMethod.method, boundMethod)) {
                    throw AssertionError("duplicate ``pathAndMethod.method`` ``pathAndMethod.path`` in ``boundMethod`` clashes with ``fun``");
                }
            }
            return resultMap;
        }
        else {
            throw Exception("path annotation missing");
        }
    }

    String canonicalizePathComponent(String path)
    {
        return "/" + path.trim("/".contains);
    }

    PathAndMethod pathForAccessor(FunctionDeclaration functionDeclaration, String rootPath)
    {
        if (nonempty a = functionDeclaration.typeParameterDeclarations) {
            throw Exception("methods with type parameters not supported: ``functionDeclaration``");
        }

        value annotations = functionDeclaration.annotations<ResourceAccessAnnotation>();
        // nonempty because method was found through annotation
        assert (nonempty annotations);

        // cannot have more than one
        ResourceAccessAnnotation ann = annotations.first;

        String pathComponent = canonicalizePathComponent(ann.path);
        log.debug("path component ``pathComponent`` for resource accessor ``functionDeclaration``.");
        String path = rootPath == "/" then pathComponent else rootPath + pathComponent;

        value pathAndMethod = PathAndMethod(path, ann.method);
        return pathAndMethod;
    }

    shared void registerTypeConverter<Result>(<Result?|ConversionError>(String?) converter)
            given Result satisfies Object
    {
        tc.putConverter(converter);
    }

    [String, ParameterStuff[], ResponseStuff] buildArgumentCreators(Function<Anything, Nothing> annotatedFunction, String ppath, String objectConsumesDefault = contentTypeFormUrlEncoded)
    {
        value functionDeclaration = annotatedFunction.declaration;

        String consumes;
        if (exists consumesAnnotation = annotations(`ConsumesAnnotation`, functionDeclaration)) {
            consumes = consumesAnnotation.contentType;
        }
        else {
            consumes = objectConsumesDefault;
        }

        variable ParameterStuff[] args = [];

        variable Boolean haveBodyParameter = false;
        variable Boolean haveFormParameter = false;
        // should this be necessary? why are parameterTypes not <Object?> ?
        assert (is Type<Object?>[] tt = annotatedFunction.parameterTypes);
        for (decl -> _ttype in zipEntries(functionDeclaration.parameterDeclarations, tt)) {
            assert (is ValueDeclaration decl);

            if (decl.defaulted) {
                log.warn("default parameter value is not supported (``decl.qualifiedName``");
            }

            ParameterStuff parameterConverter;
            // FIXME handle the case param(body) (same as no param annotation)
            if (exists paramAnnotation = annotations(`ParamAnnotation`, decl)) {
                String parameterName;
                if (paramAnnotation.name.empty) {
                    parameterName = decl.name;
                }
                else {
                    parameterName = paramAnnotation.name;
                }

                if (paramAnnotation.type == path) {
                    if (!ppath.contains("{``parameterName``}")) {
                        throw AssertionError("path parameter ``parameterName`` not in path template ``ppath``");
                    }
                }
                if (paramAnnotation.type == form) {
                    if (haveBodyParameter) {
                        throw AssertionError("form and body parameters not possible simultaneously");
                    }
                    if (consumes != "application/x-www-form-urlencoded") {
                        throw AssertionError("form parameter needs consumes(\"application/x-www-form-urlencoded\")");
                    }
                    haveFormParameter = true;
                }

                parameterConverter = buildArgumentCreator(parameterName, paramAnnotation.type, _ttype);
            }
            else {
                if (haveFormParameter) {
                    throw AssertionError("form and body parameters not possible simultaneously");
                }
                if (haveBodyParameter) {
                    throw AssertionError("no more than one body parameter allowed");
                }
                else {
                    haveBodyParameter = true;
                    parameterConverter = buildEntityExtractor(decl.name, _ttype);
                }
            }
            args = args.withTrailing(parameterConverter);
        }

		value t = annotatedFunction.type;
        return [consumes, args, ResponseStuff(t)];
    }

    SimpleParameterStuff buildArgumentCreator(String parameterName, ParamType paramType, Type<Object?> _type)
    {
        //[ClassOrInterface<>, Boolean] detailType;

        if (_type.subtypeOf(`Iterable<Anything>`) && _type.supertypeOf(`Sequential<Nothing>`)) {
            log.debug("multi-valued parameter found: ``_type``");

            // only interface is possible here!
            assert (is Interface<> _type);
            log.debug("type args: " + _type.typeArgumentList.string);

            // types in the considered hierarchy fragment above
            // all have exactly one type argument
            assert (nonempty typeArgList = _type.typeArgumentList);
            assert (typeArgList.shorterThan(2));

			value x = typeArgList.first;
			assert (is Type<Object?> x);
            value [nonNullDetailType, detailType, nullAllowed] = determineNullability(x);

            <Object?[]|ListConversionError>({String*})? listTypeConverter;
            if (nullAllowed) {
                listTypeConverter = tc.getListTypeConverterDynamicallyN(nonNullDetailType);
            }
            else {
                listTypeConverter = tc.getListTypeConverterDynamicallyNN(nonNullDetailType);
            }
            if (is Null listTypeConverter) {
                throw Exception("no converter found for ``nonNullDetailType``");
            }

            value multivaluedStringParameterExtractor = getMultivaluedStringParameterExtractor(parameterName, paramType);
            value decorated = listConverterDecorated(listTypeConverter, parameterName, paramType);
            value parameterConverter = compose(decorated, multivaluedStringParameterExtractor);

            value result = SimpleParameterStuff(parameterName, paramType, nonNullDetailType, true, nullAllowed, parameterConverter);
            return result;
        }
        else {
            value [nonNullDetailType, detailType, nullAllowed] = determineNullability(_type);

            value singlevaluedStringParameterExtractor = getSinglevaluedStringParameterExtractor(parameterName, paramType);
            value typeConverter = tc.getTypeConverterDynamically(nonNullDetailType, nullAllowed);
            if (is Null typeConverter) {
                throw Exception("no converter found for ``nonNullDetailType``");
            }

            if (nullAllowed) {
                // TODO this may not always work
                // it depends on name and presence of return value type parameter
                // may not work for subclasses of Callable without such an explicit type parameter
                value x = type(typeConverter);
                value decl = x.declaration;
                value retTypeDecl = decl.getTypeParameterDeclaration("Return");
                assert (exists retTypeDecl);
                value y = x.typeArguments[retTypeDecl];
                assert (exists y);
                log.debug("``y``");
                if (!y.supertypeOf(`Null`)) {
                    log.warn("won't return null even if allowed");
                }
            }


            value decorated = converterDecorated(typeConverter, parameterName, paramType);
            value parameterConverter = compose(decorated, singlevaluedStringParameterExtractor);

            value result = SimpleParameterStuff(parameterName, paramType, nonNullDetailType, false, nullAllowed, parameterConverter);
            return result;
        }
    }

    String?(RequestAnalyzer) getSinglevaluedStringParameterExtractor(String parameterName, ParamType parameterType)
    {
        switch (parameterType)
        case (path) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.pathParameter(parameterName);
        }
        case (query) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.queryParameter(parameterName);
        }
        case (header) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.headerParameter(parameterName);
        }
        case (cookie) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.cookieParameter(parameterName);
        }
        case (form) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.formParameter(parameterName);
        }
        case (body) {
            throw AssertionError("not supported in this program path");
        }
    }

    String[](RequestAnalyzer) getMultivaluedStringParameterExtractor(String parameterName, ParamType parameterType)
    {
        switch (parameterType)
        case (path) {
            throw AssertionError("cannot have multivalued path paremeters");
        }
        case (query) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.queryParameters(parameterName);
        }
        case (header) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.headerParameters(parameterName);
        }
        case (form) {
            return (RequestAnalyzer requestAnalyzer)
                    => requestAnalyzer.formParameters(parameterName);
        }
        else {
            throw AssertionError("implement or think more");
        }
    }

    BodyParameterStuff buildEntityExtractor(String parameterName, Type<Object?> _type)
    {
        value x = (RequestAnalyzer requestAnalyzer)
        {
            String? contentType = requestAnalyzer.contentType;
            if (is Null contentType) {
                return BodyNoConverterError(null);
            }

            value contentTypeHandler = contentTypeHandlers.get(contentType);
            if (is Null contentTypeHandler) {
                return BodyNoConverterError(contentType, _type);
            }

            value converted = contentTypeHandler.convertEntity(requestAnalyzer.body, _type);
            return converted;
        };
        return BodyParameterStuff(parameterName, _type, x);
    }
}

class ArgumentsCreator(consumes, argumentCreators, me)
{
    shared String consumes;
    shared Anything(RequestAnalyzer)[] argumentCreators;
    shared PathItem me;
}

class PathAndMethod(shared String path, shared HttpMethod method)
{
    shared actual Boolean equals(Object other)
    {
        if (!is PathAndMethod other) {
            return false;
        }
        return method == other.method && path == other.path;
    }

    shared actual Integer hash => 31 * method.hash + path.hash;

    shared actual String string => method.string + " " + path;
}

shared class RequestConversionError(errors)
{
    [[ConversionError*]+] errors;
}

shared abstract class ContentTypeHandler<out Entity>(shared String contentType)
{
    shared formal Entity|Error convertiEntity(String body);
    shared Entity|Error convertEntity(String body, Type<> _type)
    {
        if (`Entity`.subtypeOf(_type)) {
            return convertiEntity(body);
        }
        if (_type.subtypeOf(`Entity`)) {
            value converted = convertiEntity(body);
            if (is Entity converted) {
                if (!type(converted).subtypeOf(_type)) {
                    return BodyConversionError(contentType, body, _type, "Value turned out to be ``type(converted)`` instead of expected ``_type``");
                }
            }
            return converted;
        }
        else {
            return BodyNoConverterError(contentType, _type);
        }
    }
}

object jsonObjectEntityConverter extends ContentTypeHandler<JsonValue>("application/json")
{
    shared actual JsonValue|Error convertiEntity(String body)
    {
        try {
            return jsonParse(body);
        }
        catch (Exception e) {
            return BodyConversionError(contentType, body, "JsonValue", e.message);
        }
    }
}