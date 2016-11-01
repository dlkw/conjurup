import ceylon.collection {
    HashMap
}
import ceylon.language.meta.model {
    Type
}
import ceylon.language.meta {
    closedType = type,
    typeLiteral
}

shared class TypeConverters()
{
    value converterMap = HashMap<Type<>,<Object?|ConversionError>(String?)>();

    shared void putConverter<Result>(<Result?|ConversionError>(String?) converter)
    given Result satisfies Object
    {
        log.debug("putting converter `` `Result` ``->``converter``");
        if (`Result`.subtypeOf(`ConversionError`)) {
            throw AssertionError("prankster!");
        }
        converterMap.put(`Result`, converter);
    }

    // the identity string converter
    putConverter(identity);

    // converters for the basic ceylon.language types
    putConverter(makeNullPropagatingConverter(parseInteger));
    putConverter(makeNullPropagatingConverter(parseFloat));

    putConverter(booleanConverter);

    shared <Result?|ConversionError>(String?)? getTypeConverter<Result>()
    {
        value q = converterMap.get(`Result`);
        assert (is <Result?|ConversionError>(String?)? q);
        return q;
    }

    shared <Element?[]|ListConversionError>({String*})? getListTypeConverter<Element>()
    {
        value typeConverter = getTypeConverter<Element>();
        if (is Null typeConverter) {
            return null;
        }

        function listConverter({String*} input)
        {
            value allConverted = input.map(typeConverter);
            value convertedOk = errorDiscarder.discard(allConverted).sequence();

            // check for conversion errors
            if (input.longerThan(convertedOk.size)) {
                // If there was a conversion error, we re-iterate, meaning we
                // again convert all input strings.
                // But by doing this we avoid creating a sequence and re-iterate that
                // to check if there were any conversion errors.
                // So, the case without conversion errors will be quicker, but if there is
                // some conversion error, it will be slower.
                value x = { for (i->c in allConverted.indexed) if (is ConversionError c) i->c.badValue };
                value listError = ListConversionError(map(x), `Element`);
                return listError;
            }
            else {
                return convertedOk;
            }
        }

        return listConverter;
    }

    shared <Element[]|ListConversionError>({String*})? getListTypeConverter2<Element>()
    {
        // get converter for list element type
        value typeConverter = getTypeConverter<Element>();
        if (is Null typeConverter) {
            return null;
        }

        value listConverter = ({String*} input)
        {
            {<Element|ConversionError>*} allConverted = input.map(compose<Element|ConversionError, Element?|ConversionError, [String?]>(checkNotNull, typeConverter));

            value convertedOk = errorDiscarder.discard(allConverted).sequence();

            // check for conversion errors
            if (input.longerThan(convertedOk.size)) {
                // If there was a conversion error, we re-iterate, meaning we
                // again convert all input strings.
                // But by doing this we avoid creating a sequence and re-iterate that
                // to check if there were any conversion errors.
                // So, the case without conversion errors will be quicker, but if there is
                // some conversion error, it will be slower.
                value x = { for (i->c in allConverted.indexed) if (is ConversionError c) i->c.badValue };
                value listError = ListConversionError(map(x), `Element`);
                return listError;
            }
            else {
                return convertedOk;
            }
        };

        return listConverter;
    }

    shared Object?(String?)? getTypeConverterDynamically(Type<Object?> type, Boolean nullAllowed)
    {
        log.debug("looking up converter for detail type ``type``, null ``if (nullAllowed) then "allowed" else "forbidden"``");
        //value registeredConverter = converterMap.get(type[0]);

        value funDef = `function TypeConverters.getTypeConverter`;
        value method = funDef.memberApply<TypeConverters, Object?(String?)?, []>(`TypeConverters`, type);
        value fun = method.bind(this);
        //log.debug("fun is ``fun``");
        value registeredConverter = fun();
        log.debug("converter is ``registeredConverter else "not found"``");

        if (is Null registeredConverter) {
            return null;
        }

        if (nullAllowed) {
            // TODO this may not always work
            // it depends on name and presence of return value type parameter
            // may not work for subclasses of Callable without such an explicit type parameter
            value x = closedType(registeredConverter);
            value decl = x.declaration;
            value retTypeDecl = decl.getTypeParameterDeclaration("Return");
            assert (exists retTypeDecl);
            value y = x.typeArguments[retTypeDecl];
            assert (exists y);
            log.debug("``y``");
            if (!y.supertypeOf(`Null`)) {
                log.warn("won't return null even if allowed");
            }
        }
        value x = (String? s)
        => if (nullAllowed) then registeredConverter(s)
        else (registeredConverter(s) else ConversionError(null, type));
        return x;
    }

    shared <Object?[]|ListConversionError>({ String* })? getNullableListTypeConverterDynamically(Type<> type)
    {
        log.debug("looking up converter for detail type ``type``, null allowed");

        value funDef = `function TypeConverters.getListTypeConverter`;
        value method = funDef.memberApply<TypeConverters, <Object?[]|ListConversionError>({String*})?, []>(`TypeConverters`, type);
        value fun = method.bind(this);
        log.debug("fun is ``fun``");
        value registeredConverter = fun();
        log.debug("converter is ``registeredConverter else "not found"``");

        if (is Null registeredConverter) {
            return null;
        }
        return registeredConverter;
    }

    shared <Object[]|ListConversionError>({ String* })? getListTypeConverterDynamicallyNN(Type<> type)
    {
        log.debug("looking up converter for detail type ``type``, null forbidden");

        value funDef = `function TypeConverters.getListTypeConverter2`;
        value method = funDef.memberApply<TypeConverters, <Object[]|ListConversionError>({String*})?, []>(`TypeConverters`, type);
        value fun = method.bind(this);
        log.debug("fun is ``fun``");
        value registeredConverter = fun();
        log.debug("converter is ``registeredConverter else "not found"``");

        if (is Null registeredConverter) {
            return null;
        }
        return registeredConverter;
    }
}

<Element|ConversionError> checkNotNull<Element>(<Element?|ConversionError> val)
{
    if (is ConversionError val) {
        return val;
    }
    else if (exists val) {
        return val;
    }
    else {
        return ConversionError(null, `Element`);
    }
}

"Takes a standard parsing function like parseInteger and uses it to convert a String?.

 The returned converter has the following properties:
 <ul>
 <li>If the input to the given converter is null, null will be returned (hence the name nullPropagating).</li>

 <li>If a non-null input is converted to null by the given converter (signalling a conversion error),
 a ConversionError instance will be returned, indicating the bogus input value and the intended Result type.</li>

 <li>If the used parser
 </ul>"

shared <Result?|ConversionError>(String?) makeNullPropagatingConverter<Result>(Result?(String) stdParser)
given Result satisfies Object
{
    Boolean canConvertEmpty = stdParser("") exists;

    Result?|ConversionError wrap(String? arg)
    {
        log.debug("converting String ``if (exists arg) then "\"``arg``\"" else "null"`` to `` `Result?` ``");
        if (is Null arg) {
            return null;
        }
        value converted = stdParser(arg);
        if (exists converted) {
            return converted;
        }
        if (arg.empty) {
            return null;
        }
        return ConversionError(arg, `Result`);
    }
    return wrap;
}

shared Boolean|ConversionError booleanConverter(String? stringValue)
{
    if (is Null stringValue) {
        return false;
    }
    if ({ "", "true", "1", "yes", "on" }.any(stringValue.equalsIgnoringCase)) {
        return true;
    }
    if ({ "false", "0", "no", "off" }.any(stringValue.equalsIgnoringCase)) {
        return false;
    }
    return ConversionError(stringValue, `Boolean`);
}

class Discarder<S>()
{
    shared {T*} discard<T>({T|S*} input)
            => { for (ts in input) if (!is S ts) ts };
}

object errorDiscarder extends Discarder<ConversionError>(){}

shared class ConversionError(badValue, type)
        extends Error()
{
    shared String? badValue;
    shared Type<> type;

    string => if (exists badValue)
        then "\"``badValue``\" is not convertable to ``type``"
        else "null is not a value of ``type``";
}

shared class ListConversionError(badValues, type)
        extends Error()
{
    shared Map<Integer, String?> badValues;
    shared Type<> type;

    shared actual String string
    {
        StringBuilder sb = StringBuilder();
        sb.append("list entries are not convertable to ``type``: { ");
        variable Boolean first = true;
        for (k->v in badValues) {
            if (first) {
                first = false;
            }
            else {
                sb.append(", ");
            }
            if (exists v) {
                sb.append("``k``->\"``v``\"");
            }
            else {
                sb.append("``k``->null");
            }
        }
        sb.append(" }");
        return sb.string;
    }
}

shared class Error(){}
