import ceylon.io.charset {
	Charset,
	utf8
}
import ceylon.json {
	JsonValue = Value,
	JsonObject = Object,
	JsonArray = Array
}
import ceylon.io.buffer {
	ByteBuffer
}
import ceylon.language.meta {
	type
}

shared abstract class ResponseConverter(contentType, encoding)
{
	shared String contentType;
	shared Charset encoding;
	
	shared formal String convertResult(Object? result);
	
	shared ByteBuffer convertResultToByte(Object? result)
	{
		value s = convertResult(result);
		return encoding.encode(s);
	}
	
	shared formal String convertArgumentConversionError(Error[] errors);
	shared formal String createErrorMessage(Error error);

	shared ByteBuffer convertArgumentConversionErrorToByte(Error[] errors)
	{
		value s = convertArgumentConversionError(errors);
		return encoding.encode(s);
	}
}

shared object stdResponseConverter
	extends ResponseConverter("application/json", utf8)
{
	shared actual String convertResult(Object? result)
	{
		if (is JsonValue result) {
			return result?.string else "null";
		}
		else {
			throw AssertionError("unsupported result type ``type(result)``");
		}
	}
	
	shared actual String convertArgumentConversionError(Error[] errors)
	{
		{String*} messages = errors.map((error) => createErrorMessage(error));
		
		value result = JsonObject{
			"success" -> false,
			"messages" -> JsonArray{
				*messages
			},
			"total" -> errors.size
		};
		
		return result.string;
	}
	
	shared actual String createErrorMessage(Error error) => error.string;
}