import ceylon.net.http.server {
    Request
}
import ceylon.collection {
    HashMap
}

class RequestAnalyzer(Request request, String consumes)
{
    shared String? contentType = request.contentType;
    if (exists contentType) {
        if (contentType != consumes) {
            throw Exception("Unsupported content type ``contentType``. Try ``consumes``.");
        }
    }
    variable Map<String, String[]>? _queryParameterMap = null;
    Map<String, String[]> queryParameterMap
    {
        if (exists qp = _queryParameterMap) {
            return qp;
        }
        else {
            value retval = extractQueryParameters(request.queryString);
            _queryParameterMap = retval;
            return retval;
        }
    }

    shared String? pathParameter(String name)
        => request.pathParameter(name);

    shared String? queryParameter(String name)
        => if (exists list = queryParameterMap[name])
            then list.first
            else null;

    shared String[] queryParameters(String name)
            => queryParameterMap[name] else [];

    shared String? headerParameter(String name)
        => request.header(name);

    shared String[] headerParameters(String name)
            => request.headers(name);

    shared String? cookieParameter(String name)
    {
        throw Exception("unimplemented");
    }

    shared String? formParameter(String name)
    // FIXME: disregard query parameters
            => request.parameter(name, true);

    shared String[] formParameters(String name)
    // FIXME: disregard query parameters
            => request.parameters(name, true);

    shared String body => request.read();
}

Map<String, String[]> extractQueryParameters(String queryString)
{
    value map = HashMap<String, String[]>();
    for (param in queryString.split('&'.equals)) {
        String name;
        String val;
        if (exists index = param.firstIndexWhere('='.equals)) {
            value sliced = param.slice(index);
            name = param.initial(index);
            val = param.spanFrom(index + 1);
        }
        else {
            name = param;
            val = "";
        }
        if (!name.empty) {
            if (exists list = map.get(name)) {
                map.put(name, list.withTrailing(val));
            }
            else {
                map.put(name, [val]);
            }
        }
    }
    return map;
}

class BodyAnalyzerForm(Request request)
{
    shared String? formParameter(String name)
            // FIXME extract body params only (exclude query params)
            => request.parameter(name, true);

    shared String[] formParameters(String name)
            // FIXME extract body params only (exclude query params)
            => request.parameters(name, true);
}

class BodyAnalyzerEntity(Request request)
{
    shared String entity()
            => request.read();
}
