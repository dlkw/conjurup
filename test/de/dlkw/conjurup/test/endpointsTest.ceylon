import ceylon.logging {
	addLogWriter,
	writeSimpleLog
}
import ceylon.math.decimal {
	Decimal
}
import ceylon.net.http {
	get
}
import ceylon.test {
	test,
	beforeTest
}

import de.dlkw.conjurup {
	RESTServer,
	ConversionError
}
import de.dlkw.conjurup.annotations {
	param
}

beforeTest
void installLog() {
	addLogWriter(writeSimpleLog);
}

test
void endpointsTest() {
	value restServer = RESTServer();
	
//	restServer.addEndpoint("f1", get, `fun1`);
//	restServer.addEndpoint("f2", get, `fun2`);
//	restServer.addEndpoint("f3", get, `fun3`);
//	restServer.addEndpoint("f4", get, `fun4`);
//	restServer.addEndpoint("f5", get, `fun5`);
//	restServer.addEndpoint("f6", get, `fun6`);
//	
//	restServer.registerTypeConverter(nullPropagationConverter(parseDecimal));
//	restServer.addEndpoint("f7", get, `fun7`);
//	
//	restServer.addEndpoint("f8", get, `fun8`);
//
//	restServer.addEndpoint("fl1", get, `funl1`);
//	restServer.addEndpoint("fl2", get, `funl2`);
	
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

String fun1(param String arg0) {
	return "*" + arg0;
}

String fun2(param String? arg0) {
	return "*" + (arg0 else "**");
}

String fun3(param Integer arg0) {
	return "#``arg0 + 1``";
}

String fun4(param Integer? arg0) {
	if (exists arg0) {
		return "#``arg0 + 1``";
	}
	else {
		return "***";
	}
}

String fun5(param Boolean arg0) {
	return "#``!arg0``";
}

String fun6(param Boolean? arg0) {
	if (exists arg0) {
		return "#``!arg0``";
	}
	else {
		return "***";
	}
}

String fun7(param Decimal arg0) {
	return "##``arg0``";
}

String fun8(param Integer a, param Integer b) {
	return "``a + b``";
}

String funl1(param String[] a) {
	return a.reduce<String>((s, t) => t + s) else "##null";
}

String funl2(param String?[] a) {
	return a.reduce<String>((s, t) => (t else "<N1>") + (s else "<N2>")) else "##null";
}

String funl3(param Integer[] a) {
	return a.reduce<Integer>((s, t) => t + s)?.string else "##null";
}

String funl4(param Integer?[] a) {
	return a.reduce<Integer>((s, t) => (t else 0) + (s else 0))?.string else "##null";
}
