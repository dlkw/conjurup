import ceylon.buffer.charset {
    utf8
}
import ceylon.collection {
    MutableMap,
    HashMap
}
import ceylon.http.common {
    HttpMethod=Method,
    contentTypeFormUrlEncoded,
    contentType,
    get
}
import ceylon.http.server {
    Request,
    Response,
    Options,
    Endpoint,
    TemplateMatcher,
    newServer
}
import ceylon.io {
    SocketAddress
}
import ceylon.language.meta {
    closedType=type,
    annotations
}
import ceylon.language.meta.declaration {
    ValueDeclaration
}
import ceylon.language.meta.model {
    Function,
    Type,
    Interface,
    ClassOrInterface,
    UnionType,
    Class
}
import ceylon.logging {
    Logger,
    logger
}

Logger log = logger(`package de.dlkw.conjurup.core`);

[String+] prodDef = ["text/plain"];

"""
   Server for serving to HTTP requests.

   After creating and before calling start(), the server can be configured.
   Configuring consist of <ul>
   <li>adding/replacing parameter converters,</li>
   <li>adding/replacing request body deserializers,</li>
   <li>adding/replacing response body serializers,</li>
   <li>adding endpoint functions.</li>
   </ul>

   Converters are used to convert the character string parameter values of the request
   to arguments of the endpoint functions. A converter for a certain type T (say, Integer)
   will be used to fill any function arguments of types T, T?, T[], and T?[]. Instead of
   Sequentials, Iterables or Lists can also be used.

   The server is preconfigured with a converter for type String (identity)
   and with converters for the following types
   using the function makeNullPropagatingConverter:
   <ul>
   <li>Integer</li>
   <li>Float</li>
   </ul>

   For type Boolean, a special converter is preconfigured which converts the values
   "true", "1", "yes", "on", "" to true
   and "false", "0", "no", "off", null to false. With this converter, a Boolean?
   function parameter makes no sense because it will never receive a null value.
   This converter enables true/false switches like
   http://localhost/run?flag for flag==true and
   http://localhost/run for flag==false.
   You might not like this converter and wish to replace it e.g. with
   putConverter(makeNullPropagatingConverter(parseBoolean)) or any other converter.
"""
shared class Server()
{
    value httpServer = newServer({});

    value pathMap = HashMap<String, MutableMap<HttpMethod, CoProCombination0<FunctionInfo>>>();

    value tc = TypeConverters();

    value es = SerializerRegistry();
    es.registerSerializer(toStringSerializer);
    es.registerSerializer(simpleJsonSerializer);

    value ed = EntityDeserializers();

    "Starts this server in the current thread. This method will not return before the server is stopped."
    shared void start(
            socketAddress = SocketAddress("127.0.0.1", 8080),
            serverOptions = Options())
    {
        SocketAddress socketAddress;
        Options serverOptions;

        if (pathMap.empty) {
            throw Exception("No endpoint to serve");
        }

        for (path->methodMap in pathMap) {
            Endpoint endpoint = Endpoint {
                path = TemplateMatcher(path);
                acceptMethod = methodMap.keys;
                service = executeEndpoint(methodMap);
            };
            httpServer.addEndpoint(endpoint);
        }

        log.info("Server started accepting connections on ``socketAddress`` with the following endpoints:\n\t``summarizeLog()``");
        httpServer.start(socketAddress, serverOptions);
    }

    String summarizeLog()
            => "\n\t".join(pathMap.map(
        (path->methodMap) => "\n\t".join(methodMap.map(
            (method->coProCombination) => "``method`` ``path``: ``mem(coProCombination)``"))));

    String summarizeLog2()
            => "\n\t".join(pathMap.map(
        (path->methodMap) => "\n\t".join(methodMap.map(
            (method->coProCombination) => "``method`` ``path``: XXX"))));

    String mem(CoProCombination0<FunctionInfo> cpc)
    {
        StringBuilder sb = StringBuilder();
        for (s in cpc.description(FunctionInfo.functionName)) {
            sb.append("\n\t\t").append(s);
        }
        return sb.string;
    }

    void executeEndpoint(Map<HttpMethod, CoProCombination0<FunctionInfo>> methodMap)(Request rq, Response rp)
    {
        try {
            dispatchMethod(methodMap)(rq, rp);
        }
        catch (Throwable e) {
            handleException(rq, rp, e);
        }
    }

    void dispatchMethod(Map<HttpMethod, CoProCombination0<FunctionInfo>> methodMap)(Request rq, Response rp)
    {
        if (exists functionInfo = methodMap.get(rq.method)) {
            serveMethod(rq, rp, functionInfo);
        }
        else {
            // not reachable as the underlying server will
            // already have produced "405 no such method"
            throw ServerException(httpStatus.noSuchMethod);
        }
    }

    void serveMethod(Request rq, Response rp, CoProCombination0<FunctionInfo> coProCombo)
    {
        // use RFC fallback if no content type given in request
        String contentType;
        if (exists _contentType = rq.contentType) {
            contentType = _contentType;
        }
        else {
            contentType = "application/octet-stream";
            log.debug("not Content-Type header in request, falling back to ``contentType``");
        }

        String accept = rq.header("Accept") else "*/*";

        value dispatch = coProCombo.match(contentType, accept);
        if (is UnsupportedMediaTypeError dispatch) {
            throw ServerException(httpStatus.unsupportedMediaType);
        }
        if (is NotAcceptableError dispatch) {
            throw ServerException(httpStatus.notAcceptable);
        }
        value functionInfo = dispatch[1];

        functionInfo.service(rq, rp, contentType, dispatch[0]);
    }

    void handleException(Request rq, Response rp, Throwable throwable)
    {
        defaultExceptionHandler.handle(rq, rp, throwable);
    }

    /*=============== adding endpoints ====================*/

    "Makes a serializer available for its mimetype and input type.

     The Argument type is the type that the serializer will be used for, even if it can
     serialize supertypes, too."
    shared void registerSerializer<Argument>(Serializer<Argument> serializer)
    {
        es.registerSerializer<Argument>(serializer);
    }

    shared Deserializer? putDeserializer<Out>(Deserializer deserializer)
    {
        return ed.putDeserializer<Out>(deserializer);
    }

    """
       Add a function as endpoint to be served by this Server.
    """
    shared void addEndpoint<Result>(fct, method = get, path = null, consumes = null, produces = null)
    {
        "The function to serve as endpoint."
        Function<Result, Nothing> fct;

        "The URL path where to serve the endpoint. It is the part of the URL
         directly following the host name/port.

         If null (default), the function name is used."
        String? path;
        String _path = path else fct.declaration.name;

        "The HTTP method for which the server shall provide access to the endpoint."
        HttpMethod method;

        "The MIME types that this endpoint can understand as request content type."
        [String+]? consumes;

        "The MIME types that this endpoint can produce in the response body."
        [String+]? produces;

        String canonicalizedPath = canonicalizePathComponent(_path);

        value functionInfo = makeFunctionInfo<Result>(canonicalizedPath, fct, method, consumes, produces);

        assertAbsentThenPut(canonicalizedPath, method, functionInfo);
        //assertAbsentThenPut2(map({canonicalizedPath -> map({method -> functionInfo})}));
    }

    String canonicalizePathComponent(String path)
    {
        return "/" + path.trim("/".contains);
    }

    void assertAbsentThenPut(String path, HttpMethod method, FunctionInfo functionInfo)
    {
        MutableMap<HttpMethod, CoProCombination0<FunctionInfo>> storedMethodMap;
        if (exists sMM = pathMap.get(path)) {
            storedMethodMap = sMM;
        }
        else {
            storedMethodMap = HashMap<HttpMethod, CoProCombination0<FunctionInfo>>();
            pathMap.put(path, storedMethodMap);
        }

        CoProCombination0<FunctionInfo> coProCombination;
        if (exists cpc = storedMethodMap.get(method)) {
            coProCombination = cpc;
        }
        else {
            coProCombination = CoProCombination0<FunctionInfo>();
            storedMethodMap.put(method, coProCombination);
        }

        coProCombination.put(functionInfo.consumes, functionInfo.produces, functionInfo);
    }

    /*
    void assertAbsentThenPut2(Map<String, Map<HttpMethod, FunctionInfo>> newValues)
    {
        assertAllAbsent(newValues);

        for (path -> newMethodMap in newValues) {
            MutableMap<HttpMethod, FunctionInfo> storedMethodMap;
            if (exists sMM = pathMap.get(path)) {
                storedMethodMap = sMM;
            }
            else {
                storedMethodMap = HashMap<HttpMethod, FunctionInfo>();
                pathMap.put(path, storedMethodMap);
            }

            for (method -> functionInfo in newMethodMap) {
                storedMethodMap.put(method, functionInfo);
            }
        }
    }

    void assertAllAbsent(Map<String, Map<HttpMethod, FunctionInfo>> newValues)
    {
        variable String[] errs = [];
        for (path -> newMethodMap in newValues) {
            if (exists storedMethodMap = pathMap.get(path)) {
                for (newMethod -> newFunction in newMethodMap) {
                    value sFunction = storedMethodMap[newMethod];
                    if (exists sFunction) {
                        errs = errs.withTrailing("Duplicate ``newMethod`` ``path`` for ``newFunction.functionName`` clashes with ``sFunction.functionName``.");
                    }
                }
            }
        }
        if (nonempty e = errs) {
            throw PathAndMethodClashException(e);
        }
    }
    */

    FunctionInfo makeFunctionInfo<Result>(canonicalizedPath, annotatedFunction, method, consumes, producesx)
    {
        String canonicalizedPath;
        Function<Result, Nothing> annotatedFunction;
        HttpMethod method;
        [String+]? producesx;
        [String+]? consumes;

        value [allconsumes, effectiveProduces, parameterInfo, responseInfo] =
                collectInOutInfo(annotatedFunction, canonicalizedPath, method, consumes, producesx);

        value typeSerializers = es.collectSerializers<Result>(effectiveProduces);
        // FIXME
        if (is Null typeSerializers) {
            throw AssertionError("No serializers for result type `` `Result` `` found.");
        }
        value knownKeys = typeSerializers.map((e)=>e.key);
        if (nonempty missing = effectiveProduces
            .filter((s)=>!knownKeys.contains(s))
            .sequence()) {
            throw AssertionError("No serializer for result type `` `Result` `` to any of the MIME types ``missing`` found.");
        }

        void service(Request rq, Response rp, String reallyConsume, String reallyProduce)
        {
            log.debug("called endpoint ``rq.method`` ``rq.relativePath`` with ``reallyConsume`` for ``reallyProduce``");

            value serializer = typeSerializers.get(reallyProduce);
            // was checked on endpoint registration
            assert (exists serializer);

            RequestAnalyzer requestAnalyzer = RequestAnalyzer(rq);

            value convertedRequestParms = parameterInfo
                .map((p) => p.argumentCreator)
                .collect((createArg) => createArg(requestAnalyzer, reallyConsume));

            log.debug("converted request parameters are: ``convertedRequestParms``");

            variable <NamedConversionError|BodyNoConverterError|BodyConversionError>[] errors = [];
            for (x in convertedRequestParms) {
                if (is NamedConversionError|BodyNoConverterError|BodyConversionError x) {
                    errors = errors.withTrailing(x);
                }
                else {
                    value t = closedType(x);
                    log.debug("> ``x else "null"`` of type ``t``");
                }
            }

            if (errors.empty) {
                log.debug("calling ``annotatedFunction`` using arguments ``convertedRequestParms``");

                // this is the call to the developer's endpoint function!
                value result = annotatedFunction.apply(*convertedRequestParms);

                log.debug(if (exists result) then "result was ``result``" else "no result (null or void)");

                String s = serializer.serialize(result);

                rp.addHeader(contentType(reallyProduce));
                // FIXME correct charset
                rp.writeByteBuffer(utf8.encodeBuffer(s));
            }
            else {
                log.debug("conversion errors! ``errors``");
                throw ServerException(httpStatus.badRequest);
            }
        }
        return FunctionInfo(annotatedFunction.string, allconsumes, effectiveProduces, parameterInfo, service, responseInfo);
    }

    [[String+], [String+], ParameterInfo[], ResponseInfo] collectInOutInfo(
            Function<Anything, Nothing> annotatedFunction,
            String ppath,
            HttpMethod method,
            [String+]? consumes,
            [String+]? objectProducesDefault)
    {
        value functionDeclaration = annotatedFunction.declaration;

        [String+] detConsumes;
        if (exists consumes) {
            detConsumes = consumes;
        }
        else if (exists consumesAnnotation = annotations(`ConsumesAnnotation`, functionDeclaration)) {
            detConsumes = consumesAnnotation.contentTypes;
        }
        else {
            switch (method)
            case (get) {
                // no body is submitted, so any or missing Content-Type request header will be accepted
                detConsumes = ["*/*"];
            }
            else {
                // use this as default to enable form parameters
                detConsumes = [contentTypeFormUrlEncoded];
            }
        }

        [String+] produces;
        if (exists objectProducesDefault) {
            produces = objectProducesDefault;
        }
        else if (exists producesAnnotation = annotations(`ProducesAnnotation`, functionDeclaration)) {
            produces = producesAnnotation.contentTypes;
        }
        else {
            produces = prodDef;
        }

        variable ParameterInfo[] args = [];

        variable Boolean haveBodyParameter = false;
        variable Boolean haveFormParameter = false;

        // should this be necessary? why are parameterTypes not <Object?> ?
        assert (is Type<Object?>[] parameterTypes = annotatedFunction.parameterTypes);

        for (decl -> parameterType in zipEntries(functionDeclaration.parameterDeclarations, parameterTypes)) {
            assert (is ValueDeclaration decl);

            if (decl.defaulted) {
                log.warn("default parameter value is not supported (``decl.qualifiedName``");
            }

            ParameterInfo parameterConverter;
            // FIXME handle the case param(body) (same as no param annotation)
            if (exists paramAnnotation = annotations(`ParamAnnotation`, decl)) {
                String parameterName;
                if (paramAnnotation.name.empty) {
                    parameterName = decl.name;
                }
                else {
                    parameterName = paramAnnotation.name;
                }

                if (paramAnnotation.type == pathParam) {
                    if (!ppath.contains("{``parameterName``}")) {
                        throw AssertionError("path parameter ``parameterName`` not in path template ``ppath``");
                    }
                }
                if (paramAnnotation.type == form) {
                    if (haveBodyParameter) {
                        throw AssertionError("form and body parameters not possible simultaneously");
                    }
                    if (detConsumes != "application/x-www-form-urlencoded") {
                        throw AssertionError("form parameter needs consumes(\"application/x-www-form-urlencoded\")");
                    }
                    haveFormParameter = true;
                }

                parameterConverter = buildArgumentCreator(parameterName, paramAnnotation.type, parameterType);
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
                    value typeDeserializers = ed.selectDeserializer(parameterType);
                    if (is Null typeDeserializers) {
                        // FIXME
                        throw AssertionError("No deserializers to body parameter type ``parameterType`` found.");
                    }
                    value knownKeys = typeDeserializers.map((e)=>e.key);
                    if (nonempty missing = detConsumes
                        .filter((s)=>!knownKeys.contains(s))
                        .sequence()) {
                        throw AssertionError("No deserializer for any of the MIME types ``missing`` to body parameter type ``parameterType`` found.");
                    }
                    parameterConverter = BodyParameterInfo(decl.name, parameterType, selectBodyDeserializer(parameterType, typeDeserializers));
                }
            }
            args = args.withTrailing(parameterConverter);
        }

        value t = annotatedFunction.type;
        // FIXME default
        return [detConsumes, produces, args, ResponseInfo(t)];
    }

    SimpleParameterInfo buildArgumentCreator(String parameterName, ParamType paramType, Type<Object?> _type)
    {
        if (_type.subtypeOf(`Iterable<Anything>`) && _type.supertypeOf(`Sequential<Nothing>`)) {
            log.debug("multi-valued parameter found: ``_type``");

            return buildMultiValuedArgumentCreator(parameterName, paramType, _type);
        }
        else {
            log.debug("single-valued parameter found: ``_type``");

            return buildSingleValuedArgumentCreator(parameterName, paramType, _type);
        }
    }

    SimpleParameterInfo buildSingleValuedArgumentCreator(String parameterName, ParamType paramType, Type<Object?> _type)
    {
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
            value x = closedType(typeConverter);
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

        value result = SimpleParameterInfo(parameterName, paramType, nonNullDetailType, false, nullAllowed, parameterConverter);
        return result;
    }

    SimpleParameterInfo buildMultiValuedArgumentCreator(String parameterName, ParamType paramType, Type<Object?> _type)
    {
        // this must be called only if _type is subtype of Iterable and supertype of Sequential
        // (thus Iterable, List or Sequential), so only interface is possible here!
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
            listTypeConverter = tc.getNullableListTypeConverterDynamically(nonNullDetailType);
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

        value result = SimpleParameterInfo(parameterName, paramType, nonNullDetailType, true, nullAllowed, parameterConverter);
        return result;
    }

    Object? selectBodyDeserializer(Type<Object?> _type, Map<String, Deserializer> typeDeserializers)(RequestAnalyzer requestAnalyzer, String reallyConsume)
    {
        value contentTypeHandler = typeDeserializers.get(reallyConsume);
        // was checked on endpoint registration
        assert (exists contentTypeHandler);

        // FIXME use charset from Content-Type header
        value entity = utf8.decode(requestAnalyzer.body);

        // the following is
        //value result = contentTypeHandler.deserialize<T>(requestAnalyzer.body, type);
        // with the correct type argument for T dynamically applied as _type

        value dynDeserializeDecl = `function Deserializer.deserialize`;
        value dynDeserializeMethod = dynDeserializeDecl.memberApply<Deserializer, Object?, [String]>(`Deserializer`, _type);
        value dynDeserialize = dynDeserializeMethod.bind(contentTypeHandler);
        Object? result;
        try {
            result = dynDeserialize(entity);
        }
        catch (Exception e) {
            throw ServerException(httpStatus.badRequest, null, e);
        }

        return result;
    }
}

String? getSinglevaluedStringParameterExtractor(String parameterName, ParamType parameterType)(RequestAnalyzer requestAnalyzer, String ignored)
{
    switch (parameterType)
    case (pathParam) {
        return requestAnalyzer.pathParameter(parameterName);
    }
    case (query) {
        return requestAnalyzer.queryParameter(parameterName);
    }
    case (header) {
        return requestAnalyzer.headerParameter(parameterName);
    }
    case (cookie) {
        return requestAnalyzer.cookieParameter(parameterName);
    }
    case (form) {
        return requestAnalyzer.formParameter(parameterName);
    }
    case (body) {
        throw AssertionError("not supported in this program path");
    }
}

String[] getMultivaluedStringParameterExtractor(String parameterName, ParamType parameterType)(RequestAnalyzer requestAnalyzer, String ignored)
{
    switch (parameterType)
    case (pathParam) {
        throw AssertionError("cannot have multivalued path paremeters");
    }
    case (query) {
        return requestAnalyzer.queryParameters(parameterName);
    }
    case (header) {
        return requestAnalyzer.headerParameters(parameterName);
    }
    case (form) {
        return requestAnalyzer.formParameters(parameterName);
    }
    else {
        throw AssertionError("implement or think more");
    }
}

//Nothing buildArgumentCreator(String parameterName, ParamType ptype, Type<Object?> type) => nothing;

[ClassOrInterface<Object>, Type<Object?>, Boolean] determineNullability(Type<Object?> _type)
{
    if (is UnionType<Object?> _type) {
        log.debug("union of ``_type.caseTypes``");
        variable Class<Object>? tt = null;
        variable Boolean nonNullFound = false;
        for (t in _type.caseTypes) {
            if (is Class<Object> t) {
                if (nonNullFound) {
                    throw Exception("only union of one class with Null supported");
                }
                tt = t;
                nonNullFound = true;
            }
            else if (!is Class<Null> t) {
                throw Exception("only union of class with Null supported");
            }
        }
        assert (exists ttt = tt);
        return [ttt, _type, true];
    }
    else {
        assert (is ClassOrInterface<Object> _type);
        return [_type, _type, false];
    }
}

"""
   "Decorates" a converter so that it includes parameter type and name in
   the conversion error information.
"""
<Object?|NamedConversionError>(String?) converterDecorated(converter, parameterName, paramType)
{
    <Object?|ConversionError>(String?) converter;
    String parameterName;
    ParamType paramType;

    return (String? input)
    {
        value converted = converter(input);
        if (is ConversionError converted) {
            return NamedConversionError(parameterName, paramType, converted);
        }
        else {
            return converted;
        }
    };
}

"""
   "Decorates" a list converter so that it includes parameter type and name in
   the conversion error information.
"""
<Object?[]|NamedConversionError>({String*}) listConverterDecorated(converter, parameterName, paramType)
{
    <Object?[]|ListConversionError>({String*}) converter;
    String parameterName;
    ParamType paramType;

    return ({String*} input)
    {
        value converted = converter(input);
        if (is ListConversionError converted) {
            return NamedConversionError(parameterName, paramType, converted);
        }
        else {
            return converted;
        }
    };
}

shared class NamedConversionError(name, source, conversionError)
        extends Error()
{
    shared String name;
    shared ParamType source;
    shared ConversionError | ListConversionError conversionError;

    shared actual String string
    {
        if (is ConversionError conversionError) {
            return "``source`` parameter ``name`` conversion error: ``conversionError``";
        }
        else {
            return "``source`` parameters ``name`` (multi-valued) conversion error: ``conversionError``";
        }
    }
}

shared class BodyNoConverterError(contentType, type = null)
        extends Error()
{
    shared String? contentType;
    <Type<>|String>? type;

    if (is Null type) {
        assert (is Null contentType);
    }

    shared actual String string
            => if (is String contentType)
    then "No converter found to convert ``contentType`` to ``type?.string else "*"``"
    else "No Content-Type header given";
}

shared class BodyConversionError(contentType, entity, type, message)
        extends Error()
{
    shared String contentType;
    shared String entity;
    shared Type<>|String type;
    shared String message;

    shared actual String string
            => "Failed to convert body of type ``contentType`` to ``type``: ``message``";
}
