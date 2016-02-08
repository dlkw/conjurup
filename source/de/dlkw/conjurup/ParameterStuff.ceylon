import ceylon.language.meta.model {
	Type
}
import ceylon.net.http {
	Method
}
import ceylon.net.http.server {
	Request,
	Response
}
import ceylon.collection {
	ArrayList
}

abstract class ParameterStuff("the parameter's name" shared String name,
	type, argumentCreator)
      of SimpleParameterStuff | BodyParameterStuff
{
	shared Type<Object?> type;
	shared Object?(RequestAnalyzer) argumentCreator;
}

class SimpleParameterStuff(name,
	    source,
	    type,
	    isMulti,
	    nullAllowed,
        argumentCreator)
        extends ParameterStuff(name, type, argumentCreator)
{
	String name;
	shared ParamType source;
	Type<Object?> type;
	shared Boolean isMulti;
	shared Boolean nullAllowed;
	Object?(RequestAnalyzer) argumentCreator;
}

class BodyParameterStuff(String name, Type<Object?> type, argumentCreator)
        extends ParameterStuff(name, type, argumentCreator)
{
	Object?(RequestAnalyzer) argumentCreator;
}

class ResponseStuff(shared Type<> type)
{

}

class FunctionStuff(functionName, consumes, parameters, service, response)
{
	shared String functionName;

	// TODO support several content types to consume
	shared String consumes;

	shared ParameterStuff[] parameters;
	shared ResponseStuff response;
	shared Anything(Request, Response) service;
}

class EndpointStuff(functionStuff, path, methods)
{
	String path;
	Method* methods;
	FunctionStuff functionStuff;

	shared Anything(Request, Response) service => functionStuff.service;
}

class ServerStuff()
{
	value epList = ArrayList<EndpointStuff>();

	void add(EndpointStuff endpointStuff)
	{
		epList.add(endpointStuff);
	}
}
