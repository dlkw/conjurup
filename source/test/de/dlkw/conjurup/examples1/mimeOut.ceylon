import ceylon.logging {
    logger
}

import de.dlkw.conjurup.core {
    Server
}

shared void mimeOut()
{
    setupLogging();
    value log = logger(`package`);

    value server = Server();
    server.putSerializer<Object>(toStringSer);

    /*
       this serves to requests created like:

       curl "http://localhost:8080/echo?arg=hello" -H "Accept: text/plain"
       curl "http://localhost:8080/echo?arg=hello" -H "Accept: application/json"
       curl "http://localhost:8080/echo?arg=hello" -H "Accept: text/plain;q=0.8,application/json;q=0.6"

       the first and third request produce a text/plain response with body "hello" (no quotes)
       the second request produces an application/json response with body "hello" (including the quotes)
    */
    server.addEndpoint{fct =`echo`; produces=["application/json", "text/plain"];};

    server.start();
}
