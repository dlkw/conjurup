import ceylon.http.server {
    Request
}
import ceylon.collection {
    HashMap
}

class RequestAnalyzer(Request request)
{
    //shared String contentType => request.contentType;

    variable Boolean didRead = false;
    shared Byte[] body
    {
        if (didRead) {
            throw AssertionError("may read body only once");
        }
        didRead = true;
        return request.readBinary();
    }

    variable Map<String, String[]>? _queryParameterMap = null;
    Map<String, String[]> queryParameterMap
            => _queryParameterMap else (_queryParameterMap = extractQueryParameters(request.queryString));

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
            => request.formParameter(name);

    shared String[] formParameters(String name)
            => request.formParameters(name);

    Map<String, String[]> extractQueryParameters(String queryString)
    {
        value map = HashMap<String, String[]>();
        for (param in queryString.split('&'.equals)) {
            String name;
            String val;
            if (exists index = param.firstIndexWhere('='.equals)) {
                //value sliced = param.slice(index);
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
}
