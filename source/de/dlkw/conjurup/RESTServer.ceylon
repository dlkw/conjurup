import ceylon.collection {
	HashMap
}
import ceylon.json {
	JsonValue=Value,
	jsonParse=parse
}
import ceylon.language.meta {
	type,
	annotations,
	typeLiteral
}
import ceylon.language.meta.declaration {
	FunctionDeclaration,
	ValueDeclaration
}
import ceylon.language.meta.model {
	Function,
	Interface,
	Type,
	ClassOrInterface
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

import de.dlkw.conjurup.annotations {
	ResourceAccessorAnnotation,
	PathAnnotation,
	ParamAnnotation,
	ConsumesAnnotation
}

Logger log = logger(`package de.dlkw.conjurup`);

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

    "Starts this server in the current thread. This method will not return before the server is stopped."
    shared void start() => httpServer.start();

    shared void addEndpoint(path, method, annotatedFunction)
    {
        String path;
        HttpMethod method;
        Function<Object, Nothing> annotatedFunction;

        value argumentCreators = buildArgumentCreators(annotatedFunction, path);

        value service = (Request rq, Response rp)
        {
            try {
                log.debug("called endpoint ``rq.relativePath``");

                value requestAnalyzer = RequestAnalyzer(rq, argumentCreators.consumes);

                value convertedRequestParms = argumentCreators.argumentCreators.collect((Anything(RequestAnalyzer) el) => el(requestAnalyzer));
                variable Anything[] args = [];
                variable NamedConversionError[] errors = [];
                log.debug("converted request parameters are: ``convertedRequestParms``");
                for (x in convertedRequestParms) {
                    if (is NamedConversionError x) {
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
                    log.debug("result was ``result``");
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

        TemplateEndpoint endpoint = TemplateEndpoint(path, service, { method });
        httpServer.addEndpoint(endpoint);
    }

    shared void addResourceAccessor(Object obj)
    {
        value scanInfo = scanObject(obj);

        for (pathAndMethod -> fun in scanInfo) {
            addEndpoint(pathAndMethod.path, pathAndMethod.method, fun);
        }
    }

    "Scans an object for annotations to use (some of) its methods as REST resource accessors."
    Map<PathAndMethod, Function<Object, Object?[]>> scanObject(Object resource)
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

            value resultMap = HashMap<PathAndMethod, Function<Object, Object?[]>>();

            value methods = classModel.getDeclaredMethods<Nothing, Object, Object?[]>(`ResourceAccessorAnnotation`);

            for (method in methods) {
                value functionDeclaration = method.declaration;
                value pathAndMethod = pathForAccessor(functionDeclaration, rootPath);
                value boundMethod = method.bind(resource);

                if (exists fun = resultMap.put(pathAndMethod, boundMethod)) {
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
        return nothing;
    }
    
    shared void registerTypeConverter<Result>(<Result?|ConversionError>(String?) converter)
            given Result satisfies Object
    {
        tc.putConverter(converter);
    }

    ArgumentsCreator buildArgumentCreators(Function<Object, Nothing> annotatedFunction, String ppath, String objectConsumesDefault = contentTypeFormUrlEncoded)
    {
        value functionDeclaration = annotatedFunction.declaration;

        String consumes;
        if (exists consumesAnnotation = annotations(`ConsumesAnnotation`, functionDeclaration)) {
            consumes = consumesAnnotation.contentType;
        }
        else {
            consumes = objectConsumesDefault;
        }

        variable Object?(RequestAnalyzer)[] args = [];

        variable Boolean haveBodyParameter = false;
        for (decl -> _ttype in zipEntries(functionDeclaration.parameterDeclarations, annotatedFunction.parameterTypes)) {
            assert (is ValueDeclaration decl);

            if (decl.defaulted) {
                log.warn("default parameter value is not supported (``decl.qualifiedName``");
            }

            Object?(RequestAnalyzer) parameterConverter;
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

                parameterConverter = buildArgumentCreator(parameterName, paramAnnotation.type, _ttype);
            }
            else {
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

        return ArgumentsCreator(consumes, args);
    }

    Object?(RequestAnalyzer) buildArgumentCreator(String parameterName, ParamType paramType, Type<> _type)
    {
        [ClassOrInterface<>, Boolean] detailType;

        if (_type.subtypeOf(`Iterable<Anything>`) && _type.supertypeOf(`Sequential<Nothing>`)) {
            log.debug("multi-valued parameter found: ``_type``");

            // only interface is possible here!
            assert (is Interface<Anything> _type);
            log.debug("type args: " + _type.typeArgumentList.string);

            // types in the considered hierarchy fragment above
            // all have exactly one type argument
            assert (nonempty typeArgList = _type.typeArgumentList);
            assert (typeArgList.shorterThan(2));

            detailType = determineDetailType(typeArgList.first);
            
            <Object?[]|ListConversionError>({String*})? listTypeConverter;
            if (detailType[1]) {
                listTypeConverter = tc.getListTypeConverterDynamicallyN(detailType[0]);
            }
            else {
                listTypeConverter = tc.getListTypeConverterDynamicallyNN(detailType[0]);
            }
            if (is Null listTypeConverter) {
                throw Exception("no converter found for ``detailType[0]``");
            }

            value multivaluedStringParameterExtractor = getMultivaluedStringParameterExtractor(parameterName, paramType);
            value decorated = listConverterDecorated(listTypeConverter, parameterName, paramType);
            value parameterConverter = compose(decorated, multivaluedStringParameterExtractor);
            return parameterConverter;
        }
        else {
            detailType = determineDetailType(_type);

            value singlevaluedStringParameterExtractor = getSinglevaluedStringParameterExtractor(parameterName, paramType);
            value typeConverter = tc.getTypeConverterDynamically(detailType);
            if (is Null typeConverter) {
                throw Exception("no converter found for ``detailType``");
            }
            
            if (detailType[1]) {
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
            return parameterConverter;
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

    Object?(RequestAnalyzer) buildEntityExtractor(String parameterName, Type<> _type)
    {
        value x = (RequestAnalyzer requestAnalyzer)
        {
            String? contentType = requestAnalyzer.contentType;
            if (is Null contentType) {
                throw Exception("no content type given");
            }

            value contentTypeHandler = contentTypeHandlers.get(contentType);
            if (is Null contentTypeHandler) {
                throw Exception("no content type converter for ``contentType``");
            }

            value converted = contentTypeHandler.convertEntity(requestAnalyzer.body, _type);
            return converted;
        };
        return x;
    }
}

class ArgumentsCreator(consumes, argumentCreators)
{
    shared String consumes;
    shared Anything(RequestAnalyzer)[] argumentCreators;
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
    shared formal Entity convertiEntity(String body);
    shared Entity convertEntity(String body, Type<> _type)
    {
        if (_type.subtypeOf(`Entity`)) {
            return convertiEntity(body);
        }
        else {
            throw Exception("cannot convert to ``_type``");
        }
    }
}

object jsonObjectEntityConverter extends ContentTypeHandler<JsonValue>("application/json")
{
    shared actual JsonValue convertiEntity(String body) => jsonParse(body);
}