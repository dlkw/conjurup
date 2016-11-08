"""
   Finds the best match out of supported content types according to the value
   of an HTTP Accept: header.

   Implemented after  code.google.com/archive/p/mimeparse/.
"""
shared String? bestMatch({String*} supported, String accept)
{
    value parseResultsAccept = accept.split(','.equals)
        .map(parseMimeType);

    value fitnessAndQualities = supported.map((type) => fitnessAndQualityParsed(type, parseResultsAccept));
    value best = fitnessAndQualities.max((x, y) => x <=> y);
    assert (exists best);

    return best.quality != 0.0 then best.mimeType else null;
}

class ParseResult(type, subType, params)
{
    shared String type;
    shared String subType;
    shared Map<String, String> params;

    Float qTmp = if (exists qs = params["q"])
    then (parseFloat(qs) else 1.0)
    else 1.0;
    
    shared Float q = if (0.0 <= qTmp && qTmp <= 1.0) then qTmp else 1.0;
    
    shared actual String string => "('``type``', '``subType``', ``params``, q=``q``)";
}

class FitnessAndQuality(fitness, quality, mimeType)
        satisfies Comparable<FitnessAndQuality>
{
    shared Integer fitness;
    shared Float quality;
    shared String mimeType;
    
    shared actual Comparison compare(FitnessAndQuality other)
    {
        Comparison cmp = fitness <=> other.fitness;
        return if (cmp == equal)
            then quality <=> other.quality
            else cmp;
    }
}


"Parses a MIME type with parameters, like 'application/json;q=0.55', into its components."
ParseResult parseMimeType(String mimeType)
{
    value parts = mimeType.split(';'.equals);
    
    variable String fullType = parts.first.trimmed;

    String type;
    String subType;
    Integer? slashPos = fullType.firstIndexWhere('/'.equals);
    if (exists slashPos) {
        type = fullType[... slashPos - 1].trimmed;
        subType = fullType[slashPos + 1 ...].trimmed;
    }
    else {
        type = fullType.trimmed;
        subType = "*";
    }

    String[2]? sliceAtEq(String input)
    {
        Integer? eqPos = input.firstIndexWhere('='.equals);
        if (exists eqPos) {
            return [input[... eqPos - 1].trimmed, input[eqPos + 1 ...].trimmed];
        }
        return null;
    }
    
    String->String mkEntry(String[2] input)
    {
        return input[0]->input[1];
    }

    value params = map(parts.rest.map(sliceAtEq).coalesced.map(mkEntry));
    
    return ParseResult(type, subType, params);
}

FitnessAndQuality fitnessAndQualityParsed(String mimeType, {ParseResult+} supported)
{
    value target = parseMimeType(mimeType);
    
    variable Integer bestFitness = -1;
    variable Float bestFitQ = 0.0;
    
    for (sup in supported) {
        if ((target.type == sup.type || target.type == "*" || sup.type == "*")
                && (target.subType == sup.subType || target.subType == "*" || sup.subType == "*")) {
            variable Integer paramMatches = 0;
            for (paramKey->paramValue in target.params) {
                if (paramKey != "q") {
                    if (exists supValue = sup.params[paramKey], paramValue == supValue) {
                        paramMatches++;
                    }
                }
            }
                
            Integer fitness = (if (target.type == sup.type) then 100 else 0)
                    + (if (target.subType == sup.subType) then 10 else 0)
                    + paramMatches;
            if (fitness > bestFitness) {
                bestFitness = fitness;
                bestFitQ = sup.q;
            }
        }
    }
    
    return FitnessAndQuality(bestFitness, bestFitQ, mimeType);
}

// FIXME make a test out of this
shared void runin()
{
    print(parseMimeType("  application   /  json  ; q   = 0.2  ; l   = tzru  ;l=7"));
    
    print(bestMatch(["aapplication/tex", "application/xml", "text/plain", "aapplication/json"], "application/json;q=0.55,application/xml;q=0.6,*/*;q=1.0"));
}