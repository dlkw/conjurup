shared class ServerException(status, String? description = null, Throwable? cause = null) extends Exception(description, cause)
{
    shared Integer status;
}