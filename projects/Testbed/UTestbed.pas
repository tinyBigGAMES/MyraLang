{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  System.Classes,
  System.IOUtils,
  StdApp.Utils,
  StdApp.Console,
  StdApp.Console.Menu,
  Myra.Common,
  Myra.Build,
  Myra.Engine,
  Myra.Tester,
  UDemo.LSPInProcess,
  UDemo.LSPOutProcess;


procedure RegisterTests(const ATester: TTester);
begin
  // Index bands ARE the categories. Data mirrors bin/res/tests/tests.toml.

  ATester.SetCategory('Basics');
  ATester.RegisterTest(0, 'test_exe_hello', rmExecute);
  ATester.RegisterTest(1, 'test_exe_variables', rmExecute);
  ATester.RegisterTest(2, 'test_exe_vars', rmExecute);
  ATester.RegisterTest(3, 'test_exe_assign', rmExecute);
  ATester.RegisterTest(4, 'test_exe_consts', rmExecute);
  ATester.RegisterTest(5, 'test_exe_constants_enums', rmExecute);
  ATester.RegisterTest(6, 'test_exe_types', rmExecute);
  ATester.RegisterTest(7, 'test_exe_math', rmExecute);

  ATester.SetCategory('Control Flow');
  ATester.RegisterTest(50, 'test_exe_ifelse', rmExecute);
  ATester.RegisterTest(51, 'test_exe_conditional', rmExecute);
  ATester.RegisterTest(52, 'test_exe_control_flow', rmExecute);
  ATester.RegisterTest(53, 'test_exe_loops', rmExecute);
  ATester.RegisterTest(54, 'test_exe_match', rmExecute);

  ATester.SetCategory('Routines');
  ATester.RegisterTest(100, 'test_exe_routines', rmExecute);
  ATester.RegisterTest(101, 'test_exe_variadic_routines', rmExecute);
  ATester.RegisterTest(102, 'test_exe_routine_type_linkage', rmExecute);
  ATester.RegisterTest(103, 'test_exe_intrinsics', rmExecute);

  ATester.SetCategory('Data Types');
  ATester.RegisterTest(150, 'test_exe_arrays', rmExecute);
  ATester.RegisterTest(151, 'test_exe_dynamic_arrays', rmExecute);
  ATester.RegisterTest(152, 'test_exe_records', rmExecute);
  ATester.RegisterTest(153, 'test_exe_pointers', rmExecute);
  ATester.RegisterTest(154, 'test_exe_strings', rmExecute);
  ATester.RegisterTest(155, 'test_exe_strings_full', rmExecute);
  ATester.RegisterTest(156, 'test_exe_sets', rmExecute);
  ATester.RegisterTest(157, 'test_exe_sets_enum', rmExecute);
  ATester.RegisterTest(158, 'test_exe_sets_sizes', rmExecute);
  ATester.RegisterTest(159, 'test_exe_classes', rmExecute);

  ATester.SetCategory('Memory');
  ATester.RegisterTest(200, 'test_exe_memory', rmExecute);
  ATester.RegisterTest(201, 'test_exe_new_dispose', rmExecute);
  ATester.RegisterTest(202, 'test_exe_new_dispose_managed', rmExecute);
  ATester.RegisterTest(203, 'test_exe_setlength_shrink_managed', rmExecute);

  ATester.SetCategory('Exceptions');
  ATester.RegisterTest(250, 'test_exe_exceptions', rmExecute);
  ATester.RegisterTest(251, 'test_exe_exception_scope', rmExecute);

  ATester.SetCategory('Modules');
  ATester.RegisterTest(300, 'test_exe_import', rmExecute);
  ATester.RegisterTest(301, 'test_exe_std', rmExecute);

  ATester.SetCategory('Linking');
  // Dependencies come from tests.toml, NOT from the filenames -- they differ.
  // A dep inherits the target and opt level of its consumer; it is built
  // immediately before each parent build and is never tallied as a result row.
  ATester.RegisterTests(350, 'test_exe_usedll', ['test_dll_exports'], rmExecute);
  ATester.RegisterTests(351, 'test_exe_uselib', ['test_lib_utils'], rmExecute);
  // ORPHANS -- referenced by no test. Registered standalone (compile only) so
  // that dll and lib output is proven to build at all.
  ATester.RegisterTest(352, 'test_dll_mathlib', rmNone);
  ATester.RegisterTest(353, 'test_lib_math', rmNone);
  ATester.RegisterTest(354, 'test_lib_mathlib', rmNone);

  ATester.SetCategory('Tooling');
  ATester.RegisterTest(400, 'test_exe_mixedmode', rmExecute);
  ATester.RegisterTest(401, 'test_exe_target', rmExecute);
  ATester.RegisterTest(402, 'test_exe_verinfo', rmExecute);
  ATester.RegisterTest(403, 'test_exe_debug', rmDebug);
  ATester.RegisterTest(404, 'test_exe_unittest', rmExecute);

  ATester.SetCategory('Raylib');
  ATester.RegisterTest(450, 'test_exe_raylib', rmExecute);
  // Same test as 450, built with a different define (static raylib link).
  ATester.RegisterTest(451, 'test_exe_raylib', rmExecute, 'STATIC', '1');

  ATester.SetCategory('SDL3');
  ATester.RegisterTest(500, 'test_exe_sdl3', rmExecute);
  ATester.RegisterTest(501, 'test_exe_sdl3_image', rmExecute);
  ATester.RegisterTest(502, 'test_exe_sdl3_mixer', rmExecute);

  ATester.SetCategory('OpenCV');
  ATester.RegisterTest(550, 'test_exe_opencv', rmExecute);

  ATester.SetCategory('Targets');
  // These files SELF-PIN via their own @target directive, which overrides the
  // tester by design. Each is registered with the matching platform list so
  // the pin and the run agree.
  ATester.RegisterTest(9000, 'target_win64', rmExecute, [MYR_TARGET_WIN64]);
  ATester.RegisterTest(9001, 'target_winarm64', rmExecute, [MYR_TARGET_WINARM64]);
  ATester.RegisterTest(9002, 'target_linux64', rmExecute, [MYR_TARGET_LINUX64]);
  ATester.RegisterTest(9003, 'target_linuxarm64', rmExecute, [MYR_TARGET_LINUXARM64]);
  ATester.RegisterTest(9004, 'target_macos64', rmExecute, [MYR_TARGET_MACOS64]);
  ATester.RegisterTest(9005, 'target_wasm32', rmExecute, [MYR_TARGET_WASM32]);
end;

procedure RunTestbed();
var
  LTester: TTester;
  LMenu: TConsoleMenu;
  LLSPMenu: TConsoleMenu;
begin
  LLSPMenu := nil;
  try
    LTester := TTester.Create();
    try
      LTester.ShowStatus := True;
      // AUDIT: win64 only. Widen once the suite is green.
      LTester.Targets := [MYR_TARGET_WIN64];
      RegisterTests(LTester);
      LMenu := TTester.CreateMenu(LTester);
      LMenu.Title('Myra Testbed');

      // LSP demos -- appended last, so they sit at the bottom of the menu.
      // Same feature script driven over two transports: memory streams
      // in-process, and real pipes to a spawned MyraLSP.exe.
      LLSPMenu := LMenu.AddSubmenu('LSP');
      LLSPMenu.AddTestDemo(TLSPInProcessDemo);
      LLSPMenu.AddTestDemo(TLSPOutProcessDemo);

      try
        LMenu.Pause := True;
        LMenu.Run();
      finally
        LMenu.Free();
      end;
    finally
      LTester.Free();
    end;

  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);

      if TUtils.RunFromIDE() then
        TConsole.Pause();
    end;
  end;
end;

end.
