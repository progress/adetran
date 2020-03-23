# adetran
OpenSource version of OpenEdge Translation Manager and Translation Manager

This software is released as an open source project under the Apache 2.0 license.

This package contains both OpenEdge Translation Manager and the Visual Translator Tool. The software is NOT supported by Progress Software.

# Building

You will need to ensure you are in a proenv session so that $DLC environment variable is set.  The build uses gradle and an open source plugin called 'latte' to build the application.  You will need a development license of Progress OpenEdge in order to build the software.

Use the following command line to perform the build.

```

./gradlew build

```

Once the source code is built you will find the output in the build directory. The primary build output is build/tranman.pl and build/resources.  The build/resources folder contains the images that are neededd.  The build also generates build/db/kit/kit.db and build/db/xlate/xlatedb.db.

# Running

Since both Translation Manager and Visual Translator are GUI only applications, you will need to compile and build on Windows.  You can run the Visual Translator tool or the Translation Manager application using prowin.  You will need to configure the PROPATH to include both the build/tranman.pl and build/resources folder.  

You can launch the application using the sample startup programs provided for both Visual Translator and Translation Manager application.  The launcher scripts below configure the PROPATH to include the needed entries.

To launch visual translator:
```
prowin -p launch_visual_translator.p
```

To launch Translation Manager:
```
prowin -p launch_tranman.p
```

NOTE: the above wrappers are only for convenience.  They run the translation database in single user mode.

# Help

For help and instructions visit https://docs.progress.com

License Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.”
