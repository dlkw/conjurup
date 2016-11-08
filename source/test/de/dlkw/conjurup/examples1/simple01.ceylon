import ceylon.logging {
    logger,
    debug
}

import de.dlkw.conjurup.core {
    Server
}
import ceylon.http.common {
    post
}

shared void simple01()
{
    setupLogging();
    value log = logger(`package de.dlkw.conjurup.core`);
    log.priority = debug;

    value server = Server();

    /*
       this serves to requests created like:

       curl "http://localhost:8080/echo?arg=hello"

       which produces a text/plain response with body "hello" (no quotes)
    */
    server.addEndpoint(`echo`);

    /*
       this serves to requests created like:

       curl "http://localhost:8080/add2?sum1=5.1&sum2=8"
       curl "http://localhost:8080/add2?negate&sum1=5.1&sum2=8"

       which produce a text/plain response with bodies "13.1" resp. "-13.1" (no quotes).
    */
    server.addEndpoint(`add2`);

    /*
       this serves to requests created like:

       curl "http://localhost:8080/addAll?val=5&val=8&val=-20"

       which produces a text/plain response with body "-7" (no quotes).
    */
    server.addEndpoint(`addAll`);

    server.addEndpoint(`echo`, post, "/echo");

    server.start();
}
