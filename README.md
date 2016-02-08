# Conjurup a server for RESTful APIs!

This is a little framework for serving RESTful APIs written in and to be used
with the Ceylon programming language and SDK.

It is intended to run on the Java VM, since it makes use of the JVM-native
undertow module in `ceylon.net.http`.
 
**Beware:** it needs two patches to ceylon-sdk that I have submitted:

- [Path parameters](https://github.com/ceylon/ceylon-sdk/pull/481)
- [Form parameters](https://github.com/ceylon/ceylon-sdk/pull/489)

(first one is to leverage undertow to get path parameters from a
request, second one is to get form parameters from the body disregarding
query parameters)

## Supported features

* adding endpoints by specifying path, HTTP method and a function

* scanning an instance of a class for annotated methods and adding them
as endpoints

- Mandatory or optional query, form, path and header parameters of the
following types:
    * `String` or `String?`
    * `Integer` or `Integer?`
    * `Float` or `Float?`
    * `Boolean` or `Boolean?`

* Lists (`Iterable`, `List`, `Sequential`) of above types as parameters, except path, of course.
 (This was the most work as a Ceylon beginner, but fun to explore.)

* Easy extensibility of type converters to support further types
  (`ceylon.math.Decimal`, `ceylon.time.Date`, `UUID`...) as simple parameters
  of lists

* request bodies of Content-Type `application/json` available as
  `ceylon.json.Value` or subclasses

* response bodies of Content-Type `application/json` or subclasses

* some work to register Content-Type and Ceylon type specific parsers
  for the body parameter

* nice error reporting while registering functions as endpoints
  (missing type converters, clashing paths etc) and while receiving a
  request (all type conversion errors parsing the parameter strings are
  reported with value, type and parameter name)

* As a bonus, it even supports generation of a Swagger 2.0 conforming
  JSON structure defining the API!

I'm looking forward to integrate JSON serialization and deserialization to more specific Ceylon
classes once there is something available.

The code is not very beautiful, but I'll clean it up a bit, I hope.

## Usage

### Write some functions implementing endpoints

The functions you wish to make available via RESTful API may be either toplevel functions or
methods of a class.

```ceylon
import de.dlkw.conjurup.annotations {
    param,
    path,
    resourceAccess
}
import de.dlkw.conjurup {
    header,
    form}
import ceylon.net.http {
    post
}

"example for a toplevel function"
Integer addAll(param Integer aValue, param(header, "X-Val") Integer? otherValue, param Integer[] moreValues)
    => aValue
            + (otherValue else 0)
            + (moreValues.reduce<Integer>((s, t) => s + t) else 0);

"example for a method in a class"
path("/prefix")
class Accessor(String head)
{
    resourceAccess{path="sub";method=post;}
    shared String x1(param(form) String b)
        => head + "-" + b;
}
```
The `param` annotation tells conjurup to read the parameter from the query part of the URL. You can also
specify `param(header)`, `param(path)`, `param(form)` (or `param(query)`) to get the parameter
from a request header, the URL path or from the request body (`application/x-www-form-urlencoded`
content type). Omitting the annotation means "take the parameter from the request body". 

The name of the parameter is taken from the Ceylon declaration parameter name but can be overridden by
the `name` parameter of the `param` annotation.

The mandatory `path` annotation on a class defines a common URL path prefix for all endpoints from that class. Each method annotated by `resourceAccess` will be installed as an endpoint. Its `path` parameter, together with the prefix from the `path` annotation on the class, gives the path for that endpoint. The `method` parameter gives the HTTP methods that are allowed for the endpoint.

### Register the endpoints

Create an instance of RESTServer and add the functions you wish to make available, then start the server:

```ceylon
import de.dlkw.conjurup {
    RESTServer
}
import ceylon.net.http {
    get
}

shared void run() {
	value restServer = RESTServer();
	
	// for a toplevel function
	restServer.addEndpoint("add", get, `addAll`);
	
    // for methods in a class instance
    Accessor accessor = Accessor("test");
    restServer.addResourceAccessor(accessor);

	// ... add more functions or objects
	
	restServer.start();
}
``` 

This will start the server listening on `localhost:8080`.

You may not add more endpoints after the server is started.

To get the Swagger definition of your API as a JSON object, call
```ceylon
    Object swagger = restServer.swagger("title", "version", "description");
```
after it is started.

I'm not satisfied with the annotations and their names yet; it's likely that part will change.

### Adding type decoders

To support more parameter types, you can register decoders. For example, to get `ceylon.time::Date` via its
`parseDate` function:

```
restServer.registerTypeConverter(nullPropagationConverter(parseDate));
```

The `nullPropagatingConverter` is a convenience function to use "standard" Ceylon type parsing functions
with a semantic like `parseInteger`, `parseFloat` etc. To see how to use another `null`-semantics,
see the source code for TypeConverters.booleanConverter.
