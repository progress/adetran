&ANALYZE-SUSPEND _VERSION-NUMBER UIB_v8r12 GUI
&ANALYZE-RESUME
&Scoped-define WINDOW-NAME CURRENT-WINDOW
&Scoped-define FRAME-NAME Dialog-Frame
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CUSTOM _DEFINITIONS Dialog-Frame 
/*********************************************************************
* Copyright (C) 2000,2020 by Progress Software Corporation. All      *
* rights reserved. Prior versions of this work may contain portions  *
* contributed by participants of Possenet.                           *
*                                                                    *
*********************************************************************/
/*

Procedure:    adetran/pm/_newkit.w
Author:       R. Ryan
Created:      1/95 
Updated:      9/95
                11/96 SLK Long filenames
Purpose:      Dialog which allows the user to create a kit database
              and populate it with data appropriate for that kit's
              language.  
Background:   By definition kit=language, although the name of a 
              kit is only a reference to a language that
              is defined in XL_Languages and XL_Translation.  Hence,
              you could have:
              
                Kit1 German
                Kit2 French
                Kit3 French
                   
Notes:        When a kit is 'created', it is really a database that is
              created.  An alias of 'kit' is assigned that database.  An
              entry in XL_Kits is also added that identifies this kit,
              the data it was created/updated, whether it was zipped,
              whether or not it was consolidated, etc.  XL_Kits also
              has an important field, xlatedb.XL_Kits.TranslationCount
              that reflects the number of non-blank translations in the
              kit.XL_Instance.TargetPhrase field.  At this point, this
              field is 0 since the kit is just being created.
              
              After the kit has been created, it is populated as follows:
              
                kit.XL_Project    = xlatedb.XL_Project
                kit.XL_Procedure  = xlatedb.XL_Procedure
                kit.XL_Instance   = 3-way join of xlatedb.XL_String_Info,
                                    xlatedb.XL_Instance, xlatedb.XL_Translation
                kit.XL_GlossEntry = xlatedb.XL_GlossDet where XL_Glossary = s_Glossary
                
              
Called By:    pm/_kits.w
Calls:        common/_dbmgmt.p (creates the kit database)
              pm/_k-alias.p (connects to the database and sets the alias)
              pm/_copykit.p (populates the kit database)

*/
 
{ adetran/pm/tranhelp.i } /* definitions for help context strings */  

/*
** DLL declarations and variables specific to DLL calls

{adecomm/dirsrch.i}    
define var list-mem    AS MEMPTR.
define var list-char   AS CHARACTER.
define var list-size   AS INT INIT 8000.
define var missed-file AS INT.
define var DirError    AS INT.   */

define shared var _hKits      as handle  no-undo.
define shared var s_Glossary  as char    no-undo.
define shared var KitDB       as char    no-undo. 
define shared var _Kit        as char    no-undo. 
define shared var _hTrans     as handle  no-undo. 
define shared var _Lang       as char    no-undo.
define shared var _ZipPresent as logical no-undo.
define shared var _ZipName    as char    no-undo.
define shared var _ZipCommand as char    no-undo.
/* Temporary files generated by _sort.w and _order.w.                */
/* If these are blank then the regular OpenQuery internal procedures */
/* are run, otherwise these will be run                              */
DEFINE SHARED VARIABLE TmpFl_PM_Ss AS CHARACTER NO-UNDO.
{adetran/pm/vsubset.i &NEW=" " &SHARED="SHARED"}
/* NOTE that the BUFFERs and QUERY are defined as NEW SHARED
 * because they are defined as SHARED in common/_sort.w
 */
DEFINE NEW SHARED BUFFER ThisSubsetList FOR bSubsetList.
DEFINE NEW SHARED QUERY  ThisSubsetList FOR ThisSubsetList SCROLLING.
DEFINE SHARED VAR ProjectDB   AS CHARACTER NO-UNDO.
DEFINE VARIABLE iOrigHeight   AS INTEGER   NO-UNDO. /* Orig Window Height */
DEFINE VARIABLE iOrigWidth    AS INTEGER   NO-UNDO. /* Orig Window Width */
DEFINE VARIABLE hSubset       AS HANDLE    NO-UNDO. /* Subset Procedure Handle*/
DEFINE VARIABLE cOrigTitle    AS CHARACTER NO-UNDO.

define var OptionState        as logical no-undo init TRUE.
define var OKPressed          as logical no-undo.
define var Result             as logical no-undo.
define var ErrorStatus        as logical no-undo.
define var i                  as integer no-undo.
define var GlossaryList       as char    no-undo.
define var KitList            as char    no-undo.
define var ThisMessage        as char    no-undo.
define var tmpSrcLanguageName as char    no-undo.

&IF LOOKUP("{&OPSYS}","MSDOS,WIN32":U) > 0 &THEN
    &SCOPED-DEFINE SLASH ~~~\
&ELSE
    &SCOPED-DEFINE SLASH /
&ENDIF

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&ANALYZE-SUSPEND _UIB-PREPROCESSOR-BLOCK 

/* ********************  Preprocessor Definitions  ******************** */

&Scoped-define PROCEDURE-TYPE DIALOG-BOX
&Scoped-define DB-AWARE no

/* Name of first Frame and/or Browse and/or first Query                 */
&Scoped-define FRAME-NAME Dialog-Frame

/* Standard List Definitions                                            */
&Scoped-Define ENABLED-OBJECTS BtnOK KitName BtnCancel ReplaceIfExists ~
BtnHelp Btn_Options GlossaryName LanguageName SrcLanguageName KitLabel ~
LanguageLabel ContainerRectangle1 Rect2 
&Scoped-Define DISPLAYED-OBJECTS KitName ReplaceIfExists GlossaryName ~
LanguageName SrcLanguageName KitLabel LanguageLabel 

/* Custom List Definitions                                              */
/* List-1,List-2,List-3,List-4,List-5,List-6                            */

/* _UIB-PREPROCESSOR-BLOCK-END */
&ANALYZE-RESUME



/* ***********************  Control Definitions  ********************** */

/* Define a dialog box                                                  */

/* Definitions of the field level widgets                               */
DEFINE BUTTON BtnCancel AUTO-END-KEY 
     LABEL "Cancel":L 
     SIZE 15 BY 1.14.

DEFINE BUTTON BtnHelp 
     LABEL "&Help":L 
     SIZE 15 BY 1.14.

DEFINE BUTTON BtnOK AUTO-GO 
     LABEL "OK":L 
     SIZE 15 BY 1.14.

DEFINE BUTTON Btn_Options 
     LABEL "Options >>" 
     SIZE 15 BY 1.14.

DEFINE VARIABLE GlossaryName AS CHARACTER FORMAT "X(256)":U 
     LABEL "Glossary Name" 
     VIEW-AS COMBO-BOX INNER-LINES 5
     LIST-ITEMS "None" 
     DROP-DOWN-LIST
     SIZE 46 BY 1 NO-UNDO.

DEFINE VARIABLE LanguageName AS CHARACTER FORMAT "X(15)":U 
     LABEL "Target" 
     VIEW-AS COMBO-BOX INNER-LINES 2
     LIST-ITEMS "","" 
     DROP-DOWN-LIST
     SIZE 46 BY 1 NO-UNDO.

DEFINE VARIABLE SrcLanguageName AS CHARACTER FORMAT "X(256)":U INITIAL "<unnamed>" 
     LABEL "Source" 
     VIEW-AS COMBO-BOX INNER-LINES 5
     DROP-DOWN-LIST
     SIZE 46 BY 1 NO-UNDO.

DEFINE VARIABLE KitLabel AS CHARACTER FORMAT "X(256)":U INITIAL "Kit" 
      VIEW-AS TEXT 
     SIZE 4.2 BY .67 NO-UNDO.

DEFINE VARIABLE KitName AS CHARACTER FORMAT "x(30)":U 
     LABEL "&Name" 
     VIEW-AS FILL-IN NATIVE 
     SIZE 46 BY 1 NO-UNDO.

DEFINE VARIABLE LanguageLabel AS CHARACTER FORMAT "X(256)":U INITIAL "Language" 
      VIEW-AS TEXT 
     SIZE 12 BY .62 NO-UNDO.

DEFINE RECTANGLE ContainerRectangle1
     EDGE-PIXELS 2 GRAPHIC-EDGE  NO-FILL 
     SIZE 73 BY 2.62.

DEFINE RECTANGLE Rect2
     EDGE-PIXELS 2 GRAPHIC-EDGE  NO-FILL 
     SIZE 73 BY 4.76.

DEFINE VARIABLE ReplaceIfExists AS LOGICAL INITIAL no 
     LABEL "Replace If &Exists" 
     VIEW-AS TOGGLE-BOX
     SIZE 25.6 BY .67 NO-UNDO.


/* ************************  Frame Definitions  *********************** */

DEFINE FRAME Dialog-Frame
     BtnOK AT ROW 1.48 COL 77
     KitName AT ROW 1.95 COL 26 COLON-ALIGNED
     BtnCancel AT ROW 2.67 COL 77
     ReplaceIfExists AT ROW 3.14 COL 28
     BtnHelp AT ROW 3.86 COL 77
     Btn_Options AT ROW 5.05 COL 77
     GlossaryName AT ROW 5.29 COL 26 COLON-ALIGNED
     LanguageName AT ROW 6.71 COL 26 COLON-ALIGNED
     SrcLanguageName AT ROW 8.14 COL 26 COLON-ALIGNED
     KitLabel AT ROW 1.24 COL 1.8 COLON-ALIGNED NO-LABEL
     LanguageLabel AT ROW 4.57 COL 1.8 COLON-ALIGNED NO-LABEL
     ContainerRectangle1 AT ROW 1.52 COL 2
     Rect2 AT ROW 4.81 COL 2
     SPACE(19.79) SKIP(0.47)
    WITH VIEW-AS DIALOG-BOX 
         SIDE-LABELS NO-UNDERLINE THREE-D  SCROLLABLE 
         FONT 4
         TITLE "Add Kit"
         DEFAULT-BUTTON BtnOK.


/* *********************** Procedure Settings ************************ */

&ANALYZE-SUSPEND _PROCEDURE-SETTINGS
/* Settings for THIS-PROCEDURE
   Type: DIALOG-BOX
   Other Settings: COMPILE
 */
&ANALYZE-RESUME _END-PROCEDURE-SETTINGS



/* ***********  Runtime Attributes and AppBuilder Settings  *********** */

&ANALYZE-SUSPEND _RUN-TIME-ATTRIBUTES
/* SETTINGS FOR DIALOG-BOX Dialog-Frame
                                                                        */
ASSIGN 
       FRAME Dialog-Frame:SCROLLABLE       = FALSE.

/* _RUN-TIME-ATTRIBUTES-END */
&ANALYZE-RESUME

 



/* ************************  Control Triggers  ************************ */

&Scoped-define SELF-NAME Dialog-Frame
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL Dialog-Frame Dialog-Frame
ON WINDOW-CLOSE OF FRAME Dialog-Frame /* Add Kit */
DO:
  APPLY "END-ERROR":U TO SELF.
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME BtnHelp
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL BtnHelp Dialog-Frame
ON CHOOSE OF BtnHelp IN FRAME Dialog-Frame /* Help */
or help of frame {&frame-name} do:
  run adecomm/_adehelp.p ("tran":u,"context":u,{&add_kit_dialog_box}, ?).
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME BtnOK
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL BtnOK Dialog-Frame
ON CHOOSE OF BtnOK IN FRAME Dialog-Frame /* OK */
DO:           
  define var TestName as char no-undo.

  run adecomm/_setcurs.p ("wait":u).
  
  /* Before doing anything, first test to see if a name exists. */
  if KitName:screen-value = "" then do: 
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u,
                            "You must enter a kit name first").    
    apply "entry" to KitName.
    return no-apply.
  end.   
  
  apply "leave" to KitName in frame {&frame-name}.

  /* OK, it exists, but check to see if we should overwrite this  */                             
  find first xlatedb.XL_Project no-lock no-error.
  file-info:filename = xlatedb.xl_project.RootDirectory + "{&SLASH}" +
                       entry(1,KitName:screen-value,".":u) + ".db":u.
  ASSIGN sAppDir = xlatedb.xl_project.ApplDirectory.
  if file-info:full-pathname <> ? THEN DO:
    IF NOT ReplaceIfExists:checked then do:
      ThisMessage = KitName:screen-value +
                    '^Exists.  Try changing the name or specify "Replace If Exists"'. 
      run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).
      apply "entry":u to ReplaceIfExists.
      return no-apply.
    END.
    ELSE DO:
      /* Need to delete existing DB, first disconnect if connected */
      DO i = 1 TO NUM-DBS:
        IF LDBNAME(i) = ENTRY(1,KitName:SCREEN-VALUE,".":U) THEN
          DISCONNECT VALUE(LDBNAME(i)).
      END.
    END.
  end.
  
  file-info:filename = xlatedb.xl_project.RootDirectory + "{&SLASH}" +
                       entry(1,KitName:screen-value,".":u) + ".zip":u.
  if file-info:full-pathname <> ? then do:
    if NOT ReplaceIfExists:checked then do:
      ThisMessage = file-info:full-pathname +
                   '^Exists.  Try changing the name or specify "Replace If Exists"'.
      run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).
      apply "entry":u to ReplaceIfExists.
      return no-apply.
    end. 
    else os-delete value(file-info:full-pathname).
  end. 
        
  /*
  ** Were resource procedures generated?
  */
  if not xlatedb.XL_Project.ResourcesGenerated then do:
    ThisMessage = "You haven't generated any resource procedures. " +
                  "Do you want to continue building a kit?".
    run adecomm/_s-alert.p (input-output ErrorStatus, "q*":u, "yes-no":u, ThisMessage).    
    if not ErrorStatus then return no-apply.
  end.

  /* does the kit name already exist in the table? */      
  if not ReplaceIfExists:checked AND
     CAN-FIND(First xlatedb.XL_Kit WHERE xlatedb.XL_Kit.KitName = KitName:SCREEN-VALUE)
     then do:
    ThisMessage = KitName:screen-value + "^Already exists in the project and will not be replaced.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).    

    KitName:auto-zap = true.
    apply "entry":u to KitName in frame {&frame-name}.
    return no-apply.
  end.

  find xlatedb.XL_Kit where
       xlatedb.XL_Kit.KitName = ENTRY(1,KitName:screen-value,".":U) + ".db":U
     exclusive-lock no-error.  
  if available xlatedb.XL_Kit THEN DO:
    FOR EACH xlatedb.XL_Kit-Proc WHERE xlatedb.XL_Kit-Proc.KitName = xlatedb.XL_Kit.KitName
             EXCLUSIVE-LOCK:
      DELETE xlatedb.XL_Kit-Proc.
    END.
    delete xlatedb.XL_Kit.
  END.

  /* All the checks passed, so let's set the variables */   
  assign KitName             = entry(1,KitName:screen-value,".":u) + ".db":u 
         file-info:file-name = "adetran/data/xlkit.db":u
         TestName            = file-info:full-pathname
         ReplaceIfExists     = ReplaceIfExists:checked
         _Kit                = xlatedb.xl_project.RootDirectory + "{&SLASH}" + KitName
         KitDB               = _Kit
         _Lang               = LanguageName:screen-value.
  
  find xlatedb.XL_Language where xlatedb.XL_Language.lang_name = _Lang 
                           no-lock no-error.
  if not available xlatedb.XL_Language then do:  
    create xlatedb.XL_Language.
    assign xlatedb.XL_Language.lang_name = _Lang.
  end.
  
  create xlatedb.XL_Kit.
  assign xlatedb.XL_Kit.KitName       = KitName
         xlatedb.XL_Kit.Language      = _Lang
         xlatedb.XL_Kit.GlossaryName  = GlossaryName:screen-value  
         xlatedb.XL_Kit.KitGenerated  = true
         xlatedb.XL_Kit.CreateDate    = today.

  /* Create a cross-ref record for each loaded procedure 
   * For subset only list those that will be transferred */
  nextLoop:
  FOR EACH xlatedb.XL_Procedure NO-LOCK:

    IF lSubset THEN
    DO:
       FIND FIRST ThisSubsetList
         WHERE ThisSubsetList.Project   = ProjectDB
           AND ThisSubsetList.Directory = xlatedb.XL_Procedure.Directory
           AND (ThisSubsetList.FileName    = xlatedb.XL_Procedure.FileName
                OR ThisSubsetList.FileName = cAllFiles)
         NO-LOCK NO-ERROR.
       IF NOT AVAILABLE ThisSubsetList THEN NEXT nextLoop.
    END.
    CREATE xlatedb.XL_Kit-Proc.
    ASSIGN xlatedb.XL_Kit-Proc.KitName       = KitName
           xlatedb.XL_Kit-Proc.Directory     = xlatedb.XL_Procedure.Directory
           xlatedb.XL_Kit-Proc.FileName      = xlatedb.XL_Procedure.FileName
           xlatedb.XL_Kit-Proc.CurrentStatus = xlatedb.XL_Procedure.CurrentStatus.
  END.

  /* Create a new kit database  */ 
  run adecomm/_setcurs.p ("wait":u).
  run adetran/common/_dbmgmt.p (
    input "CREATE":u,
    input _Kit,
    input "kit":U,
    input TestName,
    input ReplaceIfExists,
    output ErrorStatus).

  if ErrorStatus then do:
    ThisMessage = "Kit Database could not be created.". 
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).    
    apply "entry":u to KitName in frame {&frame-name}.
    DELETE xlatedb.XL_Kit.
    FOR EACH xlatedb.XL_Kit-Proc WHERE xlatedb.XL_Kit-Proc.KitName = KitName:
      DELETE xlatedb.XL_Kit-Proc.
    END.
    return no-apply. 
  end.
       
  run adetran/common/_k-alias.p (output ErrorStatus). 
  if ErrorStatus then do:
    apply "entry":u to KitName in frame {&frame-name}. 
    return no-apply. 
  end. 
  
  /* The kit database is built at this stage: now populate it  */     
  frame {&frame-name}:hidden = true.

  /* Change source language */
  ASSIGN tmpSrcLanguageName = IF SrcLanguageName:SCREEN-VALUE = "<unnamed>":U THEN 
                                 "":U
                              ELSE
                                 SrcLanguageName:SCREEN-VALUE.
  run adetran/pm/_copykit.p (
              INPUT GlossaryName:screen-value, 
              INPUT _Lang, 
              INPUT tmpSrcLanguageName, 
              output ErrorStatus)
        NO-ERROR. 
  if ErrorStatus OR ERROR-STATUS:ERROR then do:
    ThisMessage = "Kit was not populated succesfully.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).
    DISCONNECT VALUE(REPLACE(KitName,".DB":U,"":U)).
    FOR EACH xlatedb.XL_Kit WHERE xlatedb.XL_Kit.KitName = Kitname EXCLUSIVE-LOCK:
      DELETE xlatedb.XL_Kit.
    END.
    FOR EACH xlatedb.XL_Kit-Proc WHERE xlatedb.XL_Kit-Proc.KitName = KitName EXCLUSIVE-LOCK:
      DELETE xlatedb.XL_Kit-Proc.
    END.
    return _kit.
  end.

  /* Save XL_Invalid */
  FOR EACH xlatedb.XL_Invalid: DELETE xlatedb.XL_Invalid. END.
  FOR EACH ThisSubsetList WHERE ThisSubsetList.Project = ProjectDB
                            AND ThisSubsetList.Active  = TRUE NO-LOCK:
     CREATE xlatedb.XL_Invalid.
     ASSIGN xlatedb.XL_Invalid.GlossaryName = ThisSubsetList.Directory
            xlatedb.XL_Invalid.TargetPhrase = ThisSubsetList.FileName.
  END.

  IF VALID-HANDLE(hSubset) THEN
  APPLY "CLOSE":U TO hSubset.

  run Realize in _hKits.
  run SetLanguages in _hTrans.   
  run adecomm/_setcurs.p ("").   
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME Btn_Options
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL Btn_Options Dialog-Frame
ON CHOOSE OF Btn_Options IN FRAME Dialog-Frame /* Options >> */
DO:
   IF OptionState THEN
   DO:
      run adecomm/_setcurs.p("wait":U).

      /* Set to Option state and display the full dialog. */
      ASSIGN Btn_Options:LABEL = "<< &Options"
             OptionState = NOT OptionState.
      /* FRAME {&FRAME-NAME}:HEIGHT = <Full Height> is done in _subset.w */
      RUN VALUE("adetran/pm/_subset.w") PERSISTENT SET hSubset
               (  INPUT FRAME Dialog-Frame:HANDLE
                , INPUT THIS-PROCEDURE
               ).

      run adecomm/_setcurs.p("":U).
   END.
   ELSE
   DO:
      /* Display the shortened dialog */
      ASSIGN Btn_Options:LABEL = "&Options >>"
             OptionState = NOT OptionState.
      RUN shrinkDialog.
   END.
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME GlossaryName
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL GlossaryName Dialog-Frame
ON VALUE-CHANGED OF GlossaryName IN FRAME Dialog-Frame /* Glossary Name */
DO:
  if self:screen-value = "" then return.
  find xlatedb.XL_Glossary where xlatedb.XL_Glossary.GlossaryName = self:screen-value  
                           no-lock no-error.
  if available xlatedb.XL_Glossary then do:
    assign
      LanguageName              = replace(xlatedb.XL_Glossary.GlossaryType,"/":u,",":u)
      LanguageName:list-items   = LanguageName
      LanguageName:screen-value = LanguageName:entry(2).
  end. 
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME KitName
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL KitName Dialog-Frame
ON LEAVE OF KitName IN FRAME Dialog-Frame /* Name */
DO:
  define var TestName as char no-undo.
  define var DirName  as char no-undo.
  define var UnnamedName as char no-undo.

  run adecomm/_osprefx.p (KitName:screen-value,output DirName, output UnnamedName).  
  TestName = trim(entry(1,UnnamedName,".":u)). 
  if DirName ne "" then do:
    message "All kits will be created in the project directory." view-as alert-box warning.
    assign KitName:screen-value = UnnamedName.
  end.
  assign TestName = entry(1,UnnamedName,".").
  
  /* It is illegal to have a filename be one of the two reserved keywords
     "Untitled" and "None".                                                 */
  IF CAN-DO("UNTITLED,NONE":U,TestName) 
     OR CAN-DO("UNTITLED,NONE":U,UnnamedName) THEN DO:
    ASSIGN ThisMessage = TestName + 
             " is a reserved keyword and may not be used as a Project Name.".
    RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"e*":U, "ok":U, ThisMessage).
    apply "entry":u to KitName in frame Dialog-frame.
    return no-apply.  
  END. 
  
  if self:screen-value = "" then do:
    ThisMessage = "Please enter a name for the kit.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).    
  end.
  else
  /* 11/96 Modified for long filenames */
  if length(UnnamedName,"RAW":u) > 255 then do:
    ThisMessage = KitName:screen-value + "^This filename is not valid.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":u, "ok":u, ThisMessage).    
    KitName:auto-zap = true.
    apply "entry":u to KitName in frame Dialog-frame.
    return no-apply.  
  end.
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&Scoped-define SELF-NAME SrcLanguageName
&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CONTROL SrcLanguageName Dialog-Frame
ON VALUE-CHANGED OF SrcLanguageName IN FRAME Dialog-Frame /* Source */
DO:
  if self:screen-value = "<unnamed>":U then return.
  find xlatedb.XL_Glossary where xlatedb.XL_Glossary.GlossaryName = self:screen-value  
                           no-lock no-error.
  if available xlatedb.XL_Glossary then do:
    assign
      srcLanguageName              = replace(xlatedb.XL_Glossary.GlossaryType,"/":u,",":u)
      srcLanguageName:list-items   = "<unnamed>,":U + LanguageName:entry(1).
      srcLanguageName:SCREEN-VALUE = "<unnamed>":U.
  end. 
END.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


&UNDEFINE SELF-NAME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _CUSTOM _MAIN-BLOCK Dialog-Frame 


/* ***************************  Main Block  *************************** */

/* Parent the dialog-box to the ACTIVE-WINDOW, if there is no parent.   */
IF VALID-HANDLE(ACTIVE-WINDOW) AND FRAME {&FRAME-NAME}:PARENT eq ?
THEN ASSIGN FRAME {&FRAME-NAME}:PARENT = ACTIVE-WINDOW
     CURRENT-WINDOW = ACTIVE-WINDOW.


/* Now enable the interface and wait for the exit condition.            */
/* (NOTE: handle ERROR and END-KEY so cleanup code will always fire.    */
MAIN-BLOCK:
DO ON ERROR   UNDO MAIN-BLOCK, LEAVE MAIN-BLOCK
   ON END-KEY UNDO MAIN-BLOCK, LEAVE MAIN-BLOCK:

  run adetran/pm/_getproj.p (output GlossaryList, output KitList, output ErrorStatus).

  assign
    cOrigTitle                  = FRAME {&FRAME-NAME}:TITLE
    THIS-PROCEDURE:PRIVATE-DATA = "KITCREATION":U
    GlossaryName:list-items   = left-trim(GlossaryList)
    GlossaryName:screen-value = if s_Glossary = "" then
                                  GlossaryName:entry(1) 
                                else
                                  s_Glossary
    KitLabel:screen-value      = "Kit"
    KitLabel:width             = font-table:get-text-width-chars (KitLabel:screen-value,4)
    LanguageLabel:screen-value = "Language"
    LanguageLabel:width        = font-table:get-text-width-chars (LanguageLabel:screen-value,4)
    iOrigHeight = FRAME {&FRAME-NAME}:VIRTUAL-HEIGHT-CHARS
    iOrigWidth  = FRAME {&FRAME-NAME}:VIRTUAL-WIDTH-CHARS.
     
  IF lSubset THEN RUN assignTitle.
  RUN Realize.
  WAIT-FOR GO OF FRAME {&FRAME-NAME} focus KitName.
END.
RUN disable_UI.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME


/* **********************  Internal Procedures  *********************** */

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE assignTitle Dialog-Frame 
PROCEDURE assignTitle :
   ASSIGN FRAME {&FRAME-NAME}:TITLE = IF lSubset THEN cOrigTitle + cSubset
                                      ELSE cOrigTitle.
END PROCEDURE.
   
/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE crUpdDirFileList Dialog-Frame 
PROCEDURE crUpdDirFileList :   
   FOR EACH xlatedb.XL_Procedure BREAK BY xlatedb.XL_Procedure.Directory:
      IF FIRST-OF (xlatedb.XL_Procedure.Directory) THEN
      DO:
         FIND FIRST bSubsetList
            WHERE bSubsetList.Project   = ProjectDB
              AND bSubsetList.Directory = xlatedb.XL_Procedure.Directory
              AND bSubsetList.FileName  = cAllFiles
            NO-LOCK NO-ERROR.
         IF NOT AVAILABLE bSubsetList OR NOT bSubsetList.Active THEN
         DO:
            FIND FIRST bDirList 
               WHERE bDirList.Project   = ProjectDB
                 AND bDirList.Directory = xlatedb.XL_Procedure.Directory
               NO-LOCK NO-ERROR.
            IF NOT AVAILABLE bDirList THEN
            DO:
               CREATE bDirList.
               ASSIGN bDirList.Project   = ProjectDB
                      bDirList.Directory = xlatedb.XL_Procedure.Directory.
            END.
            ASSIGN bDirList.Active = TRUE.
         END.
      END.
   
      FIND FIRST bFileList
         WHERE bFileList.Project   = ProjectDB
           AND bFileList.Directory = xlatedb.XL_Procedure.Directory
           AND bFileList.FileName  = xlatedb.XL_Procedure.FileName
          NO-LOCK NO-ERROR.
      IF NOT AVAILABLE bFileList THEN 
      DO:
         CREATE bFileList.
         ASSIGN bFileList.Project   = ProjectDB
                bFileList.Directory = xlatedb.XL_Procedure.Directory
                bFileList.FileName  = xlatedb.XL_Procedure.FileName.
      END.
      /* If there is already an active subset listing for the individual file
       * or for the complete directory, then set the filename to not active */
      FIND FIRST bSubsetList 
         WHERE bSubsetList.Project   = ProjectDB
           AND bSubsetList.Directory = bFileList.Directory
           AND bSubsetList.Active    = yes
           AND (bSubsetList.FileName = cAllFiles OR
                bsubsetList.FileName = xlatedb.XL_Procedure.FileName)
         NO-LOCK NO-ERROR.
      ASSIGN bFileList.Active = NOT AVAILABLE bSubsetList.
   END.
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE crUpdSubsetList Dialog-Frame 
PROCEDURE crUpdSubsetList :
/* 
 */

/* *********
 * No need to do this.  The subset is loaded from the database upon
 * connection, and is maintained throughout the session.
 
   FIND FIRST xlatedb.XL_Invalid NO-ERROR.
   IF AVAILABLE xlatedb.XL_Invalid THEN
   DO:
      /* Note that we are storing the subset in the XL_Invalid table */
      FOR EACH xlatedb.XL_Invalid:
         FIND FIRST ThisSubsetList
           WHERE ThisSubsetList.Project   = ProjectDB
             AND ThisSubsetList.Directory = xlatedb.XL_Invalid.GLossaryName
             AND ThisSubsetList.FileName  = xlatedb.XL_Invalid.TargetPhrase
           EXCLUSIVE-LOCK NO-ERROR. 
         IF NOT AVAILABLE ThisSubsetList THEN
         DO:
            CREATE ThisSubsetList.
            ASSIGN ThisSubsetList.Project   = ProjectDB
                   ThisSubsetList.Directory = xlatedb.XL_Invalid.GLossaryName
                   ThisSubsetList.FileName  = xlatedb.XL_Invalid.TargetPhrase. 
         END.
         ThisSubsetList.Active = TRUE.
      END.
   END.
******** */
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE disable_UI Dialog-Frame  _DEFAULT-DISABLE
PROCEDURE disable_UI :
/*------------------------------------------------------------------------------
  Purpose:     DISABLE the User Interface
  Parameters:  <none>
  Notes:       Here we clean-up the user-interface by deleting
               dynamic widgets we have created and/or hide 
               frames.  This procedure is usually called when
               we are ready to "clean-up" after running.
------------------------------------------------------------------------------*/
  /* Hide all frames. */
  HIDE FRAME Dialog-Frame.
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE enlargeDialog Dialog-Frame 
PROCEDURE enlargeDialog :
DEFINE INPUT PARAMETER  p-iExtraHeight    AS INTEGER        NO-UNDO.
   DEFINE INPUT PARAMETER  p-iExtraWidth     AS INTEGER        NO-UNDO.
   DEFINE OUTPUT PARAMETER p-iRow            AS INTEGER        NO-UNDO.
   DEFINE OUTPUT PARAMETER p-iColumn         AS INTEGER        NO-UNDO.
  
   /* Since the subset frame will be a child to procedure's frame, 
    *    p-iRow should be 
    *    p-iColumn should be 1 
    */ 
   ASSIGN 
      p-iRow                           = FRAME Dialog-Frame:HEIGHT-CHARS - 0.1
      p-iColumn                        = 1
      FRAME Dialog-Frame:HEIGHT-CHARS  = FRAME Dialog-Frame:HEIGHT-CHARS +
                                         p-iExtraHeight + .5
      FRAME Dialog-Frame:WIDTH-CHARS   = 1 + 
         MAX(FRAME Dialog-Frame:WIDTH-CHARS, p-iExtraWidth).
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE Realize Dialog-Frame 
PROCEDURE Realize :
ENABLE BtnOK BtnCancel 
         BtnHelp Btn_Options
      WITH FRAME {&frame-name}.
  {&OPEN-BROWSERS-IN-QUERY-{&frame-name}}
frame {&frame-name}:hidden = true. 

  display
    ReplaceIfExists
  with frame dialog-frame.
  RUN setLanguages.
    
  enable 
    KitName
    ReplaceIfExists
    GlossaryName  
    LanguageName
    SrcLanguageName
    BtnOK
    BtnCancel
    BtnHelp 
  with frame dialog-frame.
  apply "value-changed":u to GlossaryName.  
  frame {&frame-name}:hidden = false.                                            
  run adecomm/_setcurs.p ("").
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE SetLanguages Dialog-Frame 
PROCEDURE SetLanguages :
DO WITH FRAME {&FRAME-NAME}:
    SrcLanguageName = "".
    FOR EACH xlatedb.XL_Language NO-LOCK:
      srcLanguageName = if srcLanguageName = "" THEN 
                           xlatedb.XL_Language.Lang_Name
                        else 
                           srcLanguageName + ",":U + xlatedb.XL_Language.Lang_Name.
    END.
    ASSIGN
      srcLanguageName:list-items   = srcLanguageName + ",<unnamed>":U
      srcLanguageName:SCREEN-VALUE = "<unnamed>":U.
  END.
END PROCEDURE. /* SetLanguages */

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE shrinkDialog Dialog-Frame 
PROCEDURE shrinkDialog :
IF VALID-HANDLE(hSubset) THEN RUN disable_UI IN hSubset.

   ASSIGN FRAME Dialog-Frame:HEIGHT-CHARS    = iOrigHeight
          FRAME Dialog-Frame:WIDTH-CHARS     = iOrigWidth.
END PROCEDURE.

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

&ANALYZE-SUSPEND _UIB-CODE-BLOCK _PROCEDURE shrinkDialog-1 Dialog-Frame 
PROCEDURE shrinkDialog-1 :
RUN disable_UI IN hSubset.

  ASSIGN FRAME Dialog-Frame:HEIGHT-CHARS = iOrigHeight
         FRAME Dialog-Frame:WIDTH-CHARS  = iOrigWidth.
END PROCEDURE. /* shrinkDialog */

/* _UIB-CODE-BLOCK-END */
&ANALYZE-RESUME

