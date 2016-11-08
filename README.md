# Conjurup a server for RESTful APIs!

This is a little framework for serving RESTful APIs written in and to be used
with the Ceylon programming language and SDK.

It is intended to run on the Java VM, since it makes use of the JVM-native
undertow module in `ceylon.net.http`.

## New:

This is now adapted to ceylon.http v1.3.0, so no more patches to the SDK as in the previous
version are needed!

## Supported features

* adding endpoints by specifying path, HTTP method, consumed and produced endpoints and a function

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

* Easy extensibility of type converters to support further parameter types
  (`ceylon.math.Decimal`, `ceylon.time.Date`, `UUID`...) as simple parameters
  or lists

* request bodies can be parsed from a MIME type to a Ceylon class by registering a Deserializer
  for the class or a superclass and MIME type (included is a Deserializer for application/json to
  ceylon.json::Value and an experimental Deserializer to all Objects using Jackson)

* response bodies can be written as a MIME type after registering a Serializer for the result
  class to the MIME type (included is a Serializer for ceylon.json::Value to application/json and
  an experimental Serializer for any Object using Jackson)

* support for different charsets in Content-Type and Accept request headers is not working yet
  (does not matter for main use case application/json)

* nice error reporting while registering functions as endpoints
  (missing type converters, serializers, deserializers, clashing paths etc) and while receiving a
  request (all type conversion errors parsing the parameter strings are
  reported with value, type and parameter name)

* Experimental support for generation of a Swagger 2.0 conforming
  JSON structure defining the API will be back soon, using mbknor-jackson-jsonschema
  for JSON schema generation

I'm looking forward to integrate JSON serialization and deserialization to more specific Ceylon
classes once there is something available. I'm experiencing some problems with Jackson and
optional types (e.g. Integer|Null).

The code is now a lot cleaner.
## Changes

### v0.2.0

* code cleanup

* adapted to Ceylon SDK 1.3

* Support for MIME types: Content-Type, Accept headers and consumes/produces attributes for endpoints
  (not finished yet)
  
### v0.1.0

* initial release
  
## Usage

This is very few docs. Please see also the few examples in test.de.dlkw.conjurup::test01.

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

### Default endpoint settings

The method from the addEndpoint call is used to register the endpoint.
If none is given, GET will be used.

The path from the addEndpoint call is used to register the endpoint.
If none (null) is given, the function name will be used.

The consumed MIME types from the consumes parameter of the addEndpoint call are used to register the endpoint.
If none (null) are given, then "\*/\*" is used for GET endpoints, application/x-www-form-urlencoded is used
for POST or PUT endpoints.

The parameter locations from the param annotations in the parameter list of the endpoint function are used.
If a endpoint function parameter doesn't have a param annotation, it will be treated as a query parameter
for GET endpoints. For POST or PUT endpoints, if the consum...XXX / or request Content-Type? FIXME


### Register the endpoints

Create an instance of RESTServer and add the functions you wish to make available, then start the server:

```ceylon
import de.dlkw.conjurup.core {
    Server,
    consumes
}
import ceylon.http.common {
    get
}

shared void run() {
	value server = Server();
	
	// add additional converters, serializers, deserializers if needed
	
	// for a toplevel function
    consumes(["application/json"])
    produces(["application/json"])
	server.addEndpoint("/add", get, `addAll`);

	// ... add more functions or objects
	
	server.start();
}
``` 

This will start the server listening on `localhost:8080`.

You may not add more endpoints after the server is started.

Swagger support will come later (hopefully).

I'm not satisfied with the annotations and their names yet; it's likely that part will change.

### Adding type converters

To support more parameter types, you can register converters. For example, to get `ceylon.time::Date` via its
`parseDate` function:

```
server.registerTypeConverter(nullPropagationConverter(parseDate));
```

The `nullPropagatingConverter` is a convenience function to use "standard" Ceylon type parsing functions
with a semantic like `parseInteger`, `parseFloat` etc. To see how to use another `null`-semantics,
see the source code for TypeConverters.booleanConverter.

### Adding request body Serializers

needs to be written, see test.de.dlkw.conjurup::test01.

### Adding response body Deserializers

needs to be written, see test.de.dlkw.conjurup::test01.