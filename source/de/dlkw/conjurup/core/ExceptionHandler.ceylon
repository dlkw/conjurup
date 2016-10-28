import ceylon.http.server {
    Request,
    Response
}
import ceylon.http.common {
    Header
}

shared interface ExceptionHandler
{
    shared formal Boolean handle(Request rq, Response rp, Throwable throwable);
}

object defaultExceptionHandler satisfies ExceptionHandler
{
    shared actual Boolean handle(Request rq, Response rp, Throwable throwable)
    {
        if (is ServerException throwable) {
            rp.responseStatus = throwable.status;
            if (!throwable.message.empty) {
                rp.addHeader(Header("Content-Type", "text/plain"));
                // FIXME encoding
                rp.writeString(throwable.message);
            }
        }
        else {
            log.error("uncaught Throwable serving request", throwable);
            rp.responseStatus = httpStatus.internalServerError;
        }
        return true;
    }
}