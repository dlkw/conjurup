import de.dlkw.conjurup.core {
    Server,
    param,
    produces,
    consumes,
    Serializer,
    resourceAccess
}
import ceylon.logging {
    addLogWriter,
    writeSimpleLog,
    Logger,
    logger
}
import ceylon.http.common {
    get,
    put,
    post
}
import de.dlkw.conjurup.jackson {
    jacksonSer,
    jacksonDeser
}
import com.fasterxml.jackson.annotation {
    jsonProperty
}
import ceylon.language.meta {
    type
}

Logger log = logger(`package`);

object xmlSer extends Serializer<Object>("application/xml")
{
    shared actual String serialize(Object entity) => "xml ser of ``type(entity)``";
}

object toStringSer extends Serializer<Object>("text/plain")
{
    shared actual String serialize(Object entity) => entity.string;
}

shared void test01()
{
    addLogWriter(writeSimpleLog);

    value server = Server();

    server.putSerializer(toStringSer);

    if (exists x = server.putSerializer(jacksonSer)) {
        log.debug("replacing existing 3");
    }
    if (exists x = server.putSerializer(xmlSer)) {
        log.debug("replacing existing 3");
    }
    if (exists x = server.putDeserializer<Object>(jacksonDeser)) {
        log.debug("replacing existing 3");
    }

    server.addEndpoint(`even`, "/test01");
    server.addEndpoint(`twoparm`, "/test02");
    server.addEndpoint(`jsonBindTest`, "/test03");
    server.addEndpoint(`jsonBindTest2`, "/test04", post);
    server.addEndpoint(`plustest`, "/test05");
    server.start();
}

consumes(["*/*"])
Boolean even(param Integer b)
{
    return b % 2 == 0;
}

consumes(["*/*"])
produces(["text/plain"])
Integer twoparm(param Integer[] bs)
{
    value x = bs.fold(0)(plustest);
    return x;
}

consumes(["application/json"])
produces(["application/json"])
Integer plustest(param Integer a, param Integer? b)
{
    return a + (b else 99);
}

consumes(["application/json", "test/plain"])
produces(["application/json", "application/xml"])
OwnResponse jsonBindTest(param Integer a, param Integer? b)
{
    return OwnResponse(if (exists b) then a + b else -a, b exists);
}

consumes(["application/json"])
OwnResponse jsonBindTest2(OwnResponse valIn)
{
    log.info("in: ``valIn``");
    return OwnResponse(5+valIn.val, !valIn.flag);
}

class OwnResponse(val, shared jsonProperty("uu") Boolean flag)
{
    shared jsonProperty("value") Integer val;
    shared actual String string => "v:``val``, f:``flag``";
}

class OwnResponse2
{
    shared jsonProperty("value") Integer val;
    shared Boolean flag;
    shared new(va, jsonProperty("uu") Boolean fl)
    {
        Integer va;
        this.val = va;
        flag = fl;
    }
    shared actual String string => "v:``val``, f:``flag``";
}
