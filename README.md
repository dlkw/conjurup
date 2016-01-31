# Conjurup a server for RESTful APIs

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
  (at the moment there may only be one HTTP method at the same URL
  path)

- Mandatory or optional query, form, path and header parameters of the
following types:
    * `String` or `String?`
    * `Integer` or `Integer?`
    * `Float` or `Float?`
    * `Boolean` or `Boolean?`

* Lists (`Iterable`, `List`, `Sequential`) of above types as parameters, except path, of course.
 (This was the most work as a Ceylon beginner, but fun to learn.)

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

The functions you wish to make available via RESTful API may be toplevel functions or
methods of a class.

```ceylon
Integer addAll(param Integer aValue, param(header, "X-Val") Integer? otherValue, param Integer[] moreValues) {
	return aValue
			+ (otherValue else 0)
	        + (moreValues.reduce<Integer>((s, t) => s + t) else 0);
}
```
The `param` annotation tells conjurup to read the parameter from the query part of the URL. You can also
specify `param(header)`, `param(path)`, `param(form)` (or `param(query)`) to get the parameter
from a request header, the URL path or from the request body (`application/x-www-form-urlencoded`
content type). Omitting the annotation means "take the parameter from the request body". 

The name of the parameter is taken from the Ceylon declaration parameter name but can be overridden by
the `name` parameter of the `param` annotation.

### Register the endpoints

Create an instance of RESTServer and add the functions you wish to make available, then start the server:

```ceylon
import de.dlkw.conjurup {
    RESTServer
}
	
shared void run() {
	value restServer = RESTServer();
	
	restServer.addEndpoint("add", get, `addAll`);
	// ... more functions
	restServer.start();
}
``` 

This will start the server listening on `localhost:8080`.

You may not add more endpoints after the server is started.

To get the Swagger definition of your API as a JSON object, call
```ceylon
    Object swagger = restServer.swagger;
```
after it is started.

### Adding type decoders

To support more parameter types, you can register decoders. For example, to get `ceylon.time::Date` via its
`parseDate` function:

```
restServer.registerTypeConverter(nullPropagationConverter(parseDate));
```

The `nullPropagatingConverter` is a convenience function to use "standard" Ceylon type parsing functions
with a semantic like `parseInteger`, `parseFloat` etc. To see how to use another `null`-semantics,
see the source code for TypeConverters.booleanConverter.