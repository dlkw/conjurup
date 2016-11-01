import de.dlkw.conjurup.core {
    Server,
    Serializer,
    param,
    consumes,
    produces,
    simpleJsonSer
}
import ceylon.logging {
    logger
}
import ceylon.http.common {
    get
}
import java.lang {
    IllegalArgumentException
}

object toStringSer extends Serializer<Object>("text/plain")
{
    shared actual String serialize(Object entity) => entity.string;
}

shared void simple01()
{
    setupLogging();
    value log = logger(`package`);

    value server = Server();
    server.putSerializer<Object>(toStringSer);

    server.addEndpoint(`echo`);

    /*
       this serves requests created like:

       curl "http://localhost:8080/add2?sum1=5.1&sum2=8"
       curl "http://localhost:8080/add2?negate&sum1=5.1&sum2=8"

       which produces a text/plain response with body "13" (no quotes).
    */
    server.addEndpoint(`add2`);

    /*
       this serves requests created like:

       curl "http://localhost:8080/addAll?val=5&val=8&val=-20"

       which produces a text/plain response with body "-7" (no quotes).
    */
    server.addEndpoint(`addAll`);

    server.start();
}
produces(["application/json","text/plain"])
String echo(param String arg) => arg;

Float add2(param Float sum1, param Integer sum2, param Boolean negate)
        => if (negate) then -(sum1 + sum2) else sum1 + sum2;

Integer addAll(param Integer[] val) => val.fold(0)((s1, s2) => s1 + s2);
