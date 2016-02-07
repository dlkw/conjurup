import ceylon.json {
	JsonValue = Value,
	JsonObject=Object,
	JsonArray=Array
}
import ceylon.logging {
	addLogWriter,
	writeSimpleLog
}
import ceylon.math.decimal {
	Decimal
}
import ceylon.net.http {
	get,
	post
}
import ceylon.test {
	test,
	beforeTest
}
import ceylon.time {
	Date
}
import ceylon.time.iso8601 {
	parseDate
}

import de.dlkw.conjurup {
	RESTServer,
	ConversionError,
	form,
	nullPropagationConverter,
	query,
	header
}
import de.dlkw.conjurup.annotations {
	param,
	consumes,
    path,
    resourceAccessor
}

beforeTest
void installLog() {
	addLogWriter(writeSimpleLog);
}

test
shared void methodsTest() {
    value restServer = RESTServer();

    restServer.addEndpoint("f1", get, `fun1`);
    restServer.addEndpoint("f1", post, `fun1`);
    restServer.addEndpoint("f2", get, `fun1`);
    restServer.addEndpoint("f2", post, `fun2`);
    restServer.addEndpoint("f3", get, `fun2`);
    restServer.addEndpoint("f3", post, `fun2`);

    Res res = Res("hhh");
    restServer.addResourceAccessor(res);

    restServer.start();
}

test
shared void endpointsTest() {
	value restServer = RESTServer();

	restServer.addEndpoint("f1", get, `fun1`);
	restServer.addEndpoint("f2", get, `fun2`);
	restServer.addEndpoint("f3", get, `fun3`);
	restServer.addEndpoint("f4", get, `fun4`);
	restServer.addEndpoint("f5", get, `fun5`);
	restServer.addEndpoint("f6", get, `fun6`);

//	restServer.registerTypeConverter(nullPropagationConverter(parseDecimal));
//	restServer.addEndpoint("f7", get, `fun7`);

	restServer.addEndpoint("f8", get, `fun8`);

	restServer.addEndpoint("f9", get, `fun9`);
	restServer.addEndpoint("f9a", post, `fun9a`);
	restServer.addEndpoint("f10", get, `fun10`);

	restServer.registerTypeConverter(nullPropagationConverter(parseDate));
	restServer.addEndpoint("dateFun", get, `fun11`);

	restServer.addEndpoint("f12", post, `fun12`);
	restServer.addEndpoint("f13", get, `fun13`);
	restServer.addEndpoint("f14", post, `fun14`);

	restServer.addEndpoint("fl1", get, `funl1`);
	restServer.addEndpoint("fl1", post, `funl1`);
	restServer.addEndpoint("fl2", get, `funl2`);

	restServer.registerTypeConverter<Integer>((String? s)
	{
		if (is Null s) {
			return null;
		}
		if (s.empty) {
			return null;
		}
		Integer? val = parseInteger(s);
		if (exists val) {
			return val;
		}
		return ConversionError(s, `Integer`);
	});
	restServer.addEndpoint("fl3", get, `funl3`);
	restServer.addEndpoint("fl4", get, `funl4`);

	restServer.start();
}

String fun1(param String mandS) {
	return "*" + mandS;
}

String fun2(param String? optS) {
	return "*" + (optS else "**");
}

String fun3(param Integer mandI) {
	return "#``mandI + 1``";
}

String fun4(param Integer? optI) {
	if (exists optI) {
		return "#``optI + 1``";
	}
	else {
		return "***";
	}
}

String fun5(param Boolean mandB) {
	return "#``!mandB``";
}

String fun6(param Boolean? optB) {
	if (exists optB) {
		return "#``!optB``";
	}
	else {
		return "***";
	}
}

String fun7(param Decimal arg0) {
	return "##``arg0``";
}

String fun8(param Integer mandIa, param Integer mandIb) {
	return "``mandIa + mandIb``";
}

String fun9(param(form, "u") String s) {
	return "->``s``<-";
}

Float fun9a(param(form, "x") Float mandF) {
	return mandF / 3;
}

consumes("application/json")
String fun10(String s) {
	return "->``s``<-";
}

String fun11(param Date date) {
	return date.plusWeeks(3).string;
}

JsonObject fun12(param String?[] input) {
	value result = JsonObject {
		"in" -> JsonArray(input),
		"out" -> "ok"
	};
	return result;
}

consumes("application/json")
JsonValue fun13(JsonObject input) {
	value result = JsonObject {
		"in" -> input,
		"out" -> "ok"
	};
	return result;
}

consumes("application/json")
String fun14(JsonValue s) {
	return "->``s else "json null"``<-";
}

String funl1(param String[] mandSL) {
	return mandSL.reduce<String>((s, t) => t + s) else "##null";
}

String funl2(param String?[] optSL) {
	return optSL.reduce<String>((s, t) => (t else "<N1>") + (s else "<N2>")) else "##null";
}

String funl3(param Integer[] a) {
	return a.reduce<Integer>((s, t) => t + s)?.string else "##null";
}

String funl4(param Integer?[] a) {
	return a.reduce<Integer>((s, t) => (t else 0) + (s else 0))?.string else "##null";
}

Integer funl5(param Integer aValue, param(header, "X-Val") Integer? otherValue, param Integer[] moreValues) {
	return aValue
			+ (otherValue else 0)
	        + (moreValues.reduce<Integer>((s, t) => s + t) else 0);
}

path("/o")
class Res(String head)
{
    resourceAccessor{path="f3";}
    shared String x1(String b)
    {
        return head + "-" + b;
    }

    resourceAccessor{path="f2";method=get;}
    String x2(param String c)
    {
        return head + "+" + c + " (got)";
    }

    resourceAccessor{path="f2";method=post;}
    String x3(param String c)
    {
        return head + "+" + c + " (posted)";
    }
}