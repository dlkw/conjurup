import ceylon.json {
	JsonValue=Value,
	JsonObject=Object,
	JsonArray=Array
}
import ceylon.net.http {
	Method,
	get,
	head
}
import ceylon.language.meta.model {
	Type
}

"Creates a Swagger schema object for a RESTful API. The schema will conform to the Swagger 2.0 specification."
shared JsonObject swagger(
	"The title of the application."
	String title,
	
	"The version of the API."
	String version,
	
	"The information about the endpoints that make up the API."
	{Path*} paths,

	"A description of the application."
	String? description = null)
{
	return JsonObject {
		"swagger" -> "2.0",
		"info" -> JsonObject{
			"title" -> title, 
			"description" -> description,
			"version" -> version
		},
		"paths" -> jsonPaths(paths)
	};
}

JsonObject jsonPaths({Path*} paths)
{
	value jObj = JsonObject();
	jObj.putAll(paths.map((path) => path.path -> toPathInfo(path.items)));
	return jObj;
}

JsonObject toPathInfo(PathItem[] pathItems)
{
	value jObj = JsonObject();
	jObj.putAll(pathItems.map((pathItem)
		=> pathItem.method.string.lowercased -> toOperation(pathItem)));
	return jObj;
}

JsonObject toOperation(PathItem pathItem)
{
	value jObj = JsonObject();
	jObj.put("consumes", JsonArray(pathItem.consumes));
	// TODO still hard-coded "produces"
	jObj.put("produces", JsonArray(["application/json"]));

	JsonArray parameters = JsonArray(pathItem.parameters.map((p) => toParameter(p)));
	if (exists bp = pathItem.bodyParameter) {
		parameters.add(toBodyParameter(bp));
	}
	jObj.put("parameters", parameters);
	
	// TODO still generic response
	variable String[] types = [];
	if (exists rType = pathItem.response) {
		if (`JsonObject`.subtypeOf(rType)) {
			types = types.withTrailing("object");
		}
		if (`JsonArray`.subtypeOf(rType)) {
			types = types.withTrailing("array");
		}
		if (`String`.subtypeOf(rType)) {
			types = types.withTrailing("string");
		}
		if (`Float`.subtypeOf(rType)) {
			types = types.withTrailing("number");
		}
		else if (`Integer`.subtypeOf(rType)) {
			types = types.withTrailing("integer");
		}
		if (`Boolean`.subtypeOf(rType)) {
			types = types.withTrailing("boolean");
		}
		if (`Null`.subtypeOf(rType)) {
			types = types.withTrailing("null");
		}
	}
	JsonObject schema = JsonObject {
		"type" -> JsonArray(types)
	};
	jObj.put("responses", JsonObject{
		"default" -> JsonObject{
			"description" -> "a generic response",
			"schema" -> schema
		}
	});
	return jObj;
}

JsonObject toParameter(Parameter p)
{
	value jo = JsonObject();
	jo.put("name", p.name);
	jo.put("in", p.location.string);
	jo.put("required", p.required);
	jo.put("type", p.type);
	if (exists format = p.format) {
		jo.put("format", format);
	}
	if (p.allowEmptyValue) {
		jo.put("allowEmptyValue", p.allowEmptyValue);
	}
	if (p.type == "array") {
		assert (exists spit = p.arrayItems);
		jo.put("items", toItems(spit));
		jo.put("collectionFormat", p.collectionFormat);
	}
	return jo;
}

JsonObject toItems(PIT pit)
{
	value jo = JsonObject();
	jo.put("type", pit.type);
	jo.put("format", pit.format);
	if (pit.type == "array") {
		assert (exists spit = pit.spit);
		jo.put("items", toItems(spit));
		jo.put("collectionFormat", pit.collectionFormat);
	}
	return jo;
}

JsonObject toBodyParameter(BP bp)
{
	return JsonObject {
		"name" -> bp.name,
		"in" -> "body",
		"required" -> bp.required,
		"schema" -> bp.schema
	};
}

JsonObject createSchema(String type)
{
	return JsonObject { type + "-schema-TBD" -> null };
}

shared class Path(path, items)
{
	shared String path;
	shared PathItem[] items;
}

shared class PathItem(method, consumes, parameters, bodyParameter, response)
{
	shared Method method;

	switch (method.string)
	case ("GET" | "PUT" | "POST" | "DELETE" | "OPTIONS" | "HEAD" | "PATH") {
	}
	else {
		throw AssertionError("method ``method`` not supported by swagger");
	}
	
	shared String[] consumes;
	shared Parameter[] parameters;
	shared BP? bodyParameter;
	shared Type<>? response;
	
}

shared class PIT(type, format, spit)
{
	shared String type;
	shared String format;
	
	shared String collectionFormat = "multi"; // TODO cfg
	shared PIT? spit;
}

shared class BP(name, schema, required)
{
	shared String name;
	shared JsonObject schema;
	shared Boolean required;
}

shared class ParameterLocation
    of query | path | header | formData | body
		
{
	shared actual String string;
	abstract new init(String name)
	{
		this.string = name;
	}
	
	shared new query extends init("query"){}
	shared new path extends init("path"){}
	shared new header extends init("header"){}
	shared new formData extends init("formData"){}
	shared new body extends init("body"){}
}

shared class Parameter(name, location, description, type, format, allowEmptyValue, arrayItems, _required = null)
{
	shared String name;

	shared ParameterLocation location; // query, path, header, form, body
	switch (location)
	case (ParameterLocation.body) {
		throw AssertionError("location ``location`` not allowed here");
	}
	else {
		// acceptable
	}
	
	shared String? description;
	shared String type;
	shared String? format;

	shared Boolean allowEmptyValue;
	
	shared PIT? arrayItems;
	
	shared String collectionFormat = "multi"; // TODO cfg
	
	Boolean? _required;
	shared Boolean required;
	Boolean isPathParameter = location == ParameterLocation.path;
	if (exists _required) {
		if (isPathParameter && !_required) {
			throw AssertionError("path parameters are always required");
		}
		required = _required;
	}
	else {
		required = isPathParameter;
	}
}

shared void r()
{
	value ps = [Parameter("a", ParameterLocation.query, "descr", "string", "", false, null, true),
	  Parameter("b", ParameterLocation.query, "descr", "integer", "", false, null, true),
	  Parameter("c", ParameterLocation.query, "descr", "array", "", false, 
	  	PIT("integer", "", null), false)];
	value mps = [PathItem(get, ["application/json"], ps, null, `JsonObject`), PathItem(head, ["application/json"], ps, null, `Integer`)];
	Path ep = Path("/fun1", mps);
	
	JsonObject swaggerJ = swagger("spectitle", "0.1", [ep], "testdesc");
	print(swaggerJ.string);
}