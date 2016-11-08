import de.dlkw.conjurup.core {
    param
}

String echo(param String arg) => arg;
String echo2(param String arg) => "echo2: ``arg``";
String echo3(param String arg) => "echo3: ``arg``";

Float add2(param Float sum1, param Integer sum2, param Boolean negate)
        => if (negate) then -(sum1 + sum2) else sum1 + sum2;

Integer addAll(param Integer[] val) => val.fold(0)((s1, s2) => s1 + s2);
