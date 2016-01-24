import ceylon.io.charset {
	Charset,
	utf8
}
import ceylon.json {
	JsonObject = Object,
	JsonArray = Array
}
import ceylon.io.buffer {
	ByteBuffer
}

shared abstract class ResponseConverter(contentType, encoding)
{
	shared String contentType;
	shared Charset encoding;
	
	shared formal String convertArgumentConversionError(NamedConversionError[] errors);
	shared formal String createErrorMessage(NamedConversionError error);

	shared default ByteBuffer convertArgumentConversionErrorToByte(NamedConversionError[] errors)
	{
		value s = convertArgumentConversionError(errors);
		return encoding.encode(s);
	}
}

shared object stdResponseConverter
	extends ResponseConverter("application/json", utf8)
{
	shared actual String convertArgumentConversionError(NamedConversionError[] errors)
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
	
	shared actual String createErrorMessage(NamedConversionError error) => error.string;
}