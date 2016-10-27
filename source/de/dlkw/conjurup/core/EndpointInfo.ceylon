import ceylon.language.meta.model {
    Type
}
import ceylon.http.server {
    Request,
    Response
}

"Information about an annotated function that serves as an endpoint."
class FunctionInfo(functionName, consumes, produces, parameters, service, response)
{
    shared String functionName;

    shared [String+] consumes;
    shared [String+] produces;

    shared ParameterInfo[] parameters;
    shared ResponseInfo response;
    shared Anything service(Request rq, Response rp, String reallyConsume, String reallyProduce);
}

//BodyParameterInfo(ParameterInfo

"Information about an endpoint parameter."
abstract class ParameterInfo(name, type, argumentCreator)
        of SimpleParameterInfo | BodyParameterInfo
{
    "the parameter's name"
    shared String name;

    shared Type<Object?> type;
    shared Object? argumentCreator(RequestAnalyzer requestAnalyzer, String reallyConsumes);
}

class SimpleParameterInfo(name,
source,
type,
isMulti,
nullAllowed,
argumentCreator)
        extends ParameterInfo(name, type, argumentCreator)
{
    String name;
    shared ParamType source;
    Type<Object?> type;
    shared Boolean isMulti;
    shared Boolean nullAllowed;
    Object? argumentCreator(RequestAnalyzer requestAnalyzer, String reallyConsume);
}

class BodyParameterInfo(String name, Type<Object?> type, argumentCreator)
        extends ParameterInfo(name, type, argumentCreator)
{
    Object? argumentCreator(RequestAnalyzer requestAnalyzer, String reallyConsume);
}

class ResponseInfo(type)
{
    shared Type<> type;
}

shared abstract class ParamType() of pathParam | query | header | cookie | form | body {}
shared object pathParam extends ParamType() {string=>"path";}
shared object query extends ParamType() {string=>"query";}
shared object header extends ParamType() {string=>"header";}
shared object cookie extends ParamType() {string=>"cookie";}
shared object form extends ParamType() {string=>"form";}
shared object body extends ParamType() {string=>"body";}
