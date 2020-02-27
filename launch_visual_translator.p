// this is a sample  launcher for visual translator.

PROPATH = "build/lib/tranman.pl,build/resources," + PROPATH .

connect value("-db build/db/kit/kit.db -1").
connect value("-db build/db/xlate/xlatedb.db -1").

run wrappers/_vtran.p.

session:exit-code = 0.

quit.