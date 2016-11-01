import ceylon.logging {
    writeSimpleLog,
    addLogWriter,
    Priority
}
import ceylon.language.meta.declaration {
    Module,
    Package
}
import ceylon.time {
    now
}

void setupLogging()
{
    addLogWriter{void log(Priority priority, Package|Module category, String message, Throwable? throwable)
        {
            variable String logEntry = "[``now()``][``priority.string.pad(5)``] ``category`` ``message``";
            if (exists throwable) {
                value sb = StringBuilder();
                variable String? line = null;
//                printStackTrace(throwable, (s) { /*print("<``s``>");*/ return if (s != operatingSystem.newline) then sb.appendCharacter('\t').append(s).append(operatingSystem.newline) else null;});
                printStackTrace(throwable, (s) {
                    if (s != operatingSystem.newline) {
                        if (sb.empty) {
                            sb.append("!\t").append(s);
                        } else {
                            sb.append(operatingSystem.newline).append("!\t").append(s);
                        }
                    }
                });
                logEntry = operatingSystem.newline.join({logEntry, sb});
            }
            print(logEntry);
        }
    };

}

