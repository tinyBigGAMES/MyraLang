{===============================================================================
  StdApp Components™

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information

 -------------------------------------------------------------------------------

  StdApp.Resources - Shared resource strings

  Central repository of all user-facing message strings used across
  StdApp units. All error messages, warning text, and format strings
  are declared as resourcestring constants for localization readiness
  and clean separation from logic.

  Categories: severity names, error formats, fatal/IO messages,
  VFS messages, VirtualMemory messages.

  Dependencies: none
  Notes: Error code constants are defined in the unit of their concern,
    not here. This unit holds only the message text.
===============================================================================}

unit StdApp.Resources;

{$I StdApp.Defines.inc}

interface

resourcestring

  //--------------------------------------------------------------------------
  // Severity Names
  //--------------------------------------------------------------------------
  RSSeverityHint    = 'Hint';
  RSSeverityWarning = 'Warning';
  RSSeverityError   = 'Error';
  RSSeverityFatal   = 'Fatal';
  RSSeverityNote    = 'Note';
  RSSeverityUnknown = 'Unknown';

  //--------------------------------------------------------------------------
  // Error Format Strings
  //--------------------------------------------------------------------------
  RSErrorFormatSimple              = '%s %s: %s';
  RSErrorFormatWithLocation        = '%s: %s %s: %s';
  RSErrorFormatRelatedSimple       = '  %s: %s';
  RSErrorFormatRelatedWithLocation = '  %s: %s: %s';

  //--------------------------------------------------------------------------
  // Fatal / I/O Messages
  //--------------------------------------------------------------------------
  RSFatalFileNotFound  = 'File not found: ''%s''';
  RSFatalFileReadError = 'Cannot read file ''%s'': %s';
  RSFatalInternalError = 'Internal error: %s';

  //--------------------------------------------------------------------------
  // VFS Messages
  //--------------------------------------------------------------------------
  RSVFSOpenFileFailed      = 'Failed to open file: ''%s''';
  RSVFSInvalidMagic        = 'Invalid VFS archive magic signature';
  RSVFSInvalidVersion      = 'Unsupported VFS archive version: %d';
  RSVFSTruncated           = 'VFS archive is truncated or corrupt';
  RSVFSNotOpen             = 'VFS archive is not open';
  RSVFSEntryNotFound       = 'Entry not found in VFS: ''%s''';
  RSVFSScanDirFailed       = 'Failed to scan directory: ''%s''';
  RSVFSEmptyDirectory      = 'Source directory contains no files: ''%s''';
  RSVFSSourceOpenFailed    = 'Failed to open source file for packing: ''%s''';
  RSVFSException           = 'Unexpected exception in VFS: %s';

  //--------------------------------------------------------------------------
  // VirtualMemory Messages
  //--------------------------------------------------------------------------
  RSVMAllocSizeZero          = 'Cannot allocate a zero-size buffer';
  RSVMCreateMappingFailed    = 'CreateFileMapping failed (error %d)';
  RSVMMappingNameExists      = 'Mapping name "%s" already exists';
  RSVMMapViewFailed          = 'MapViewOfFile failed (error %d)';
  RSVMAllocException         = 'Allocate exception: %s';
  RSVMSharedNameEmpty        = 'OpenShared: mapping name must not be empty';
  RSVMOpenMappingFailed      = 'OpenFileMapping failed for "%s" (error %d)';
  RSVMMapViewNamedFailed     = 'MapViewOfFile failed for "%s" (error %d)';
  RSVMSharedException        = 'OpenShared exception for "%s": %s';
  RSVMUseAllocate            = 'Use Allocate() for anonymous buffers, not Open()';
  RSVMOpenFileFailed         = 'Cannot open file "%s" (error %d)';
  RSVMFileEmpty              = 'File "%s" is empty -- cannot memory-map';
  RSVMCreateMappingNamedFailed = 'CreateFileMapping failed for "%s" (error %d)';
  RSVMOpenException          = 'Open exception for "%s": %s';
  RSVMLoadAlignmentFailed    = 'File size (%d) is not aligned to element size (%d)';
  RSVMLoadException          = 'LoadFromFile exception for "%s": %s';
  RSVMFlushFailed            = 'FlushViewOfFile failed (error %d)';
  RSVMGrowNotAnonymous       = 'Grow is only valid for anonymous (vmAllocate) buffers';
  RSVMGrowNotShared          = 'Grow is not valid for shared consumer mappings';
  RSVMGrowMappingFailed      = 'Grow: CreateFileMapping failed (error %d)';
  RSVMGrowMapViewFailed      = 'Grow: MapViewOfFile failed (error %d)';
  RSVMGrowException          = 'Grow exception: %s';

  //--------------------------------------------------------------------------
  // Your Application
  //--------------------------------------------------------------------------
  // Add your application-specific resource strings below this line.
  // This section is reserved for custom messages, labels, and format
  // strings that are unique to your application. StdApp framework
  // resources are defined above and should not be modified.
  //--------------------------------------------------------------------------

  //--------------------------------------------------------------------------
  // Myra.Build - status, error, and warning messages
  //--------------------------------------------------------------------------
  RSMyraBuildTargetPlatform = 'Target platform: %s';
  RSMyraBuildOptimizeLevel  = 'Optimize level: %s';
  RSMyraBuildSubsystem      = 'Subsystem: %s';
  RSMyraBuildSaving         = 'Saving build file...';
  RSMyraBuildBuilding       = 'Building %s...';
  RSMyraBuildSucceeded      = 'Build succeeded.';
  RSMyraBuildFailedWithCode = 'Build failed with exit code %d.';
  RSMyraBuildOutput         = 'Output: %s';
  RSMyraBuildCopying        = 'Copying %s...';
  RSMyraBuildDllNotFound    = 'DLL not found: %s';
  RSMyraBuildZigNotFound    = 'Zig compiler not found: %s';
  RSMyraBuildFailed         = 'Zig build failed with exit code %d.';
  RSMyraBuildCannotRunLib   = 'Cannot run a library target.';
  RSMyraBuildCannotRunCross = 'Cannot run cross-compiled target: %s';
  RSMyraBuildWslNotFound    = 'Cannot run %s: WSL is not installed. Install WSL to run Linux targets from Windows.';
  RSMyraBuildWasmAssetNotFound = 'Wasm runner asset not found: %s';
  RSMyraBuildWasmRunnerWritten = 'Wasm runner: %s';
  RSMyraBuildWasmRunnerFailed  = 'Failed to create or launch the wasm runner: %s';
  RSMyraBuildRunningWasm       = 'Opening %s in the default browser...';
  RSMyraBuildNoProjectName  = 'No project name specified.';
  RSMyraBuildExeNotFound    = 'Executable not found: %s';
  RSMyraBuildRunFailed      = 'Program exited with code %d.';
  RSMyraBuildRunning        = 'Running %s...';
  RSMyraBuildFileNotFound   = 'Build file not found: %s';
  RSMyraBuildSaveFailed     = 'Failed to save build file: %s';
  RSMyraBuildNoOutputPath   = 'No output path specified.';
  RSMyraBuildNoSources      = 'No source files specified.';
  RSMyraBuildManifestFailed = 'Failed to add manifest to executable.';
  RSMyraBuildIconNotFound   = 'Icon file not found: %s';

  //--------------------------------------------------------------------------
  // Lexer Messages
  //--------------------------------------------------------------------------
  RSMorLexerUnexpectedChar       = 'Unexpected character: ''%s''';
  RSMorLexerUnterminatedString   = 'Unterminated string literal';
  RSMorLexerUnterminatedComment  = 'Unterminated block comment';
  RSMorLexerInvalidNumber        = 'Invalid number format: %s';
  RSMorLexerUnterminatedTriple   = 'Unterminated triple-quoted string';

  //--------------------------------------------------------------------------
  // Parser Messages
  //--------------------------------------------------------------------------
  RSMorParserExpectedToken       = 'Expected %s but found ''%s''';
  RSMorParserUnexpectedTopLevel  = 'Unexpected top-level token: ''%s''';
  RSMorParserExpectedIdentifier  = 'Expected identifier but found ''%s''';
  RSMorParserExpectedLBrace      = 'Expected ''{'' to open block';
  RSMorParserExpectedRBrace      = 'Expected ''}'' to close block';
  RSMorParserExpectedSemicolon   = 'Expected '';''';
  RSMorParserUnexpectedExpr      = 'Unexpected token in expression: ''%s''';

  //--------------------------------------------------------------------------
  // Interpreter Messages
  //--------------------------------------------------------------------------
  RSMorInterpUndefinedVar        = 'Undefined variable: ''%s''';
  RSMorInterpUndefinedRoutine    = 'Undefined routine: ''%s''';
  RSMorInterpUnknownBuiltin      = 'Unknown built-in function: ''%s''';
  RSMorInterpTypeMismatch        = 'Type error: expected %s, got %s';
  RSMorInterpNilNode             = 'Nil node dereference';
  RSMorInterpChildOutOfBounds    = 'Child index %d out of bounds (count: %d)';
  RSMorInterpEmitterCrash        = 'Emitter crash on node ''%s'': %s';
  RSMorInterpBuiltinCrash        = 'Builtin ''%s'' crash on node ''%s'': %s';
  RSMorInterpBadIndexType        = 'getChild index has unexpected type: %s (value: %s, node: %s)';

  //--------------------------------------------------------------------------
  // User Lexer Messages
  //--------------------------------------------------------------------------
  RSUserLexerUnexpectedChar      = 'Unexpected character: ''%s''';
  RSUserLexerUnterminatedString  = 'Unterminated string literal';
  RSUserLexerUnterminatedComment = 'Unterminated comment';
  RSUserLexerUnknownDirective    = 'Unknown directive: ''%s''';

  //--------------------------------------------------------------------------
  // User Parser Messages
  //--------------------------------------------------------------------------
  RSUserParserExpectedToken      = 'Expected %s but found ''%s''';
  RSUserParserNoPrefixHandler    = 'Unexpected token in expression: ''%s''';


  //--------------------------------------------------------------------------
  // Engine Status Messages
  //--------------------------------------------------------------------------
  RSMorLexerTokenizing           = 'Tokenizing language definition: %s...';
  RSMorParserParsing             = 'Parsing language definition: %s...';
  RSMorInterpSetup               = 'Setting up language tables...';
  RSUserLexerTokenizing          = 'Tokenizing %s...';
  RSUserParserParsing            = 'Parsing %s...';
  RSUserSemanticAnalyzing        = 'Analyzing %s...';
  RSUserCodeGenEmitting          = 'Emitting %s...';
  RSEngineTargetPlatform          = 'Target: %s';
  RSEngineBuildMode               = 'Build mode: %s';
  RSEngineOptimizeLevel           = 'Optimization: %s';
  RSEngineCppPassthrough          = 'Registering C++ passthrough...';

  //--------------------------------------------------------------------------
  // Engine API Messages
  //--------------------------------------------------------------------------
  RSEngineAPIMorNotLoaded = 'LoadMor must be called before ParseSource';
  RSEngineAPISrcNotParsed = 'ParseSource must be called before RunSemantics';
  RSEngineAPISemNotRun    = 'RunSemantics must be called before RunEmitters';
  RSEngineAPIEmitNotRun   = 'RunEmitters must be called before Build';
  RSEngineAPIDebugWin64   = 'Debugging is only supported for Win64 targets';

  //--------------------------------------------------------------------------
  // Language Server Messages
  //--------------------------------------------------------------------------
  RSLSPModuleNotFound  = 'Imported module not found: ''%s''';
  RSLSPLangDefFailed   = 'Language definition failed to load: ''%s''';

implementation

end.
