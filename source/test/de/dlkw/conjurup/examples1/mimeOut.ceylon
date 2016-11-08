import ceylon.logging {
    logger,
    debug
}

import de.dlkw.conjurup.core {
    Server,
    Serializer
}

shared void mimeOut()
{
    setupLogging();
    value log = logger(`package de.dlkw.conjurup.core`);
    log.priority = debug;

    value server = Server();

    object xmlSer extends Serializer<Object>("application/xml")
    {
        shared actual String serialize(Object entity) => "<xmlfake>``entity``</xmlfake>";
    }

    server.registerSerializer(xmlSer);

    /*
       this serves to requests created like:

       curl -v "http://localhost:8080/echo?arg=hello" -H "Accept: text/plain"
       curl -v "http://localhost:8080/echo?arg=hello" -H "Accept: application/json"
       curl -v "http://localhost:8080/echo?arg=hello" -H "Accept: text/plain;q=0.8,application/json;q=0.6"

       the first and third request produce a text/plain response with body "hello" (no quotes)
       the second request produces an application/json response with body "hello" (including the quotes)
    */
    server.addEndpoint{fct = `echo`; produces=["application/json", "text/plain"];};


    /*
       the following two calls serve to requests created like:

       curl -v "http://localhost:8080/echoA?arg=hello" -H "Content-Type: text/plain"
       curl -v "http://localhost:8080/echoA?arg=hello" -H "Content-Type: text/plain" -H "Accept: application/xml"
       curl -v "http://localhost:8080/echoA?arg=hello" -H "Content-Type: application/json" -H "Accept: application/xml"
       curl -v "http://localhost:8080/echoA?arg=hello" -H "Content-Type: application/json" -H "Accept: text/plain"

       the first request produces a text/plain response with body "echo2: hello" (no quotes)
       the second and third fourth request produces an application/xml response with body "<xmlfake>echo3: hello</xmlfake>" (no quotes)
       the fourth request produces a text/plain response with body "echo3: hello" (no quotes)
    */
    server.addEndpoint{fct = `echo2`; path="/echoA"; consumes=["text/plain"]; produces=["text/plain"];};
    server.addEndpoint{fct = `echo3`; path="/echoA"; consumes=["*/*"]; produces=["text/plain", "application/xml"];};

    server.start();
}
