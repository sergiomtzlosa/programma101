#!/usr/bin/env python3
import hashlib, os, plistlib, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "Programma101.xcodeproj")

def oid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

APP = oid("target-app")
TESTS = oid("target-tests")
PROJECT_ID = oid("project")
MAIN_GROUP = oid("group-main")
SOURCES_GROUP = oid("group-sources")
ENGINE_GROUP = oid("group-engine")
APP_GROUP = oid("group-app")
TESTS_GROUP = oid("group-tests")
RES_GROUP = oid("group-resources")
PRODUCTS_GROUP = oid("group-products")
FRAMEWORKS_GROUP = oid("group-frameworks")
CONFIG_LIST_PROJECT = oid("config-list-project")
CONFIG_LIST_APP = oid("config-list-app")
CONFIG_LIST_TESTS = oid("config-list-tests")

engine_files = [
    "PCSNumber.h", "PCSNumber.m",
    "PCSInstruction.h", "PCSInstruction.m",
    "PCSProgram.h", "PCSProgram.m",
    "PCSCard.h", "PCSCard.m",
    "PCS101Machine.h", "PCS101Machine.m",
]
app_files = [
    "main.m", "PCSAppDelegate.h", "PCSAppDelegate.m",
    "PCSMachineWindowController.h", "PCSMachineWindowController.m",
    "PCSKeyboardView.h", "PCSKeyboardView.m",
]

def file_type(name):
    if name.endswith(".h"):
        return "sourcecode.c.h"
    if name.endswith(".m"):
        return "sourcecode.c.objc"
    if name.endswith(".plist"):
        return "text.plist.xml"
    return "text"

file_refs = {}
for group, files in ((ENGINE_GROUP, engine_files), (APP_GROUP, app_files)):
    for f in files:
        file_refs[f] = oid("file-" + group + "-" + f)

info_ref = oid("file-info-plist")
examples_ref = oid("file-examples")
icon_ref = oid("file-app-icon")
test_ref = oid("file-test")
app_product_ref = oid("product-app")
tests_product_ref = oid("product-tests")
cocoa_ref = oid("framework-cocoa")

def buildfile(name, target):
    return oid("build-" + target + "-" + name)

def pbx_object_lines():
    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tobjects = {")
    lines.append("")

    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for f in engine_files + app_files:
        if not f.endswith(".m"):
            continue
        if f in engine_files:
            for target, label in ((APP, "app"), (TESTS, "tests")):
                bid = buildfile(f, label)
                lines.append("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
                             % (bid, f, file_refs[f], f))
        else:
            bid = buildfile(f, "app")
            lines.append("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
                         % (bid, f, file_refs[f], f))
    test_build = buildfile("PCS101EngineTests.m", "tests")
    lines.append("\t\t%s /* PCS101EngineTests.m in Sources */ = {isa = PBXBuildFile; fileRef = %s /* PCS101EngineTests.m */; };"
                 % (test_build, test_ref))
    cocoa_build = buildfile("Cocoa.framework", "app")
    lines.append("\t\t%s /* Cocoa.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = %s /* Cocoa.framework */; };"
                 % (cocoa_build, cocoa_ref))
    examples_build = buildfile("examples", "app")
    lines.append("\t\t%s /* examples in Resources */ = {isa = PBXBuildFile; fileRef = %s /* examples */; };"
                 % (examples_build, examples_ref))
    icon_build = buildfile("AppIcon.icns", "app")
    lines.append("\t\t%s /* AppIcon.icns in Resources */ = {isa = PBXBuildFile; fileRef = %s /* AppIcon.icns */; };"
                 % (icon_build, icon_ref))
    lines.append("/* End PBXBuildFile section */")
    lines.append("")

    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    for f in engine_files:
        lines.append("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = \"<group>\"; };"
                     % (file_refs[f], f, file_type(f), f))
    for f in app_files:
        lines.append("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = \"<group>\"; };"
                     % (file_refs[f], f, file_type(f), f))
    lines.append("\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };"
                 % info_ref)
    lines.append("\t\t%s /* PCS101EngineTests.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PCS101EngineTests.m; sourceTree = \"<group>\"; };"
                 % test_ref)
    lines.append("\t\t%s /* examples */ = {isa = PBXFileReference; lastKnownFileType = folder; path = examples; sourceTree = \"<group>\"; };"
                 % examples_ref)
    lines.append("\t\t%s /* AppIcon.icns */ = {isa = PBXFileReference; lastKnownFileType = image.icns; path = AppIcon.icns; sourceTree = \"<group>\"; };"
                 % icon_ref)
    lines.append("\t\t%s /* Programma101.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Programma101.app; sourceTree = BUILT_PRODUCTS_DIR; };"
                 % app_product_ref)
    lines.append("\t\t%s /* Programma101Tests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = Programma101Tests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };"
                 % tests_product_ref)
    lines.append("\t\t%s /* Cocoa.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Cocoa.framework; path = System/Library/Frameworks/Cocoa.framework; sourceTree = SDKROOT; };"
                 % cocoa_ref)
    lines.append("/* End PBXFileReference section */")
    lines.append("")

    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    fw_app = oid("phase-frameworks-app")
    fw_tests = oid("phase-frameworks-tests")
    lines.append("\t\t%s /* Frameworks */ = {" % fw_app)
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t\t%s /* Cocoa.framework in Frameworks */," % cocoa_build)
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Frameworks */ = {" % fw_tests)
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")

    # PBXGroup
    lines.append("/* Begin PBXGroup section */")
    lines.append("\t\t%s = {" % MAIN_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for g in (SOURCES_GROUP, TESTS_GROUP, RES_GROUP, FRAMEWORKS_GROUP, PRODUCTS_GROUP):
        lines.append("\t\t\t\t%s," % g)
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Sources */ = {" % SOURCES_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for g in (ENGINE_GROUP, APP_GROUP):
        lines.append("\t\t\t\t%s," % g)
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = Sources;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Engine */ = {" % ENGINE_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for f in engine_files:
        lines.append("\t\t\t\t%s /* %s */," % (file_refs[f], f))
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = Engine;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* App */ = {" % APP_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for f in app_files:
        lines.append("\t\t\t\t%s /* %s */," % (file_refs[f], f))
    lines.append("\t\t\t\t%s /* Info.plist */," % info_ref)
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = App;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Tests */ = {" % TESTS_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\t%s /* PCS101EngineTests.m */," % test_ref)
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = Tests;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Resources */ = {" % RES_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\t%s /* examples */," % examples_ref)
    lines.append("\t\t\t\t%s /* AppIcon.icns */," % icon_ref)
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = Resources;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Frameworks */ = {" % FRAMEWORKS_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\t%s /* Cocoa.framework */," % cocoa_ref)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Frameworks;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Products */ = {" % PRODUCTS_GROUP)
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\t%s /* Programma101.app */," % app_product_ref)
    lines.append("\t\t\t\t%s /* Programma101Tests.xctest */," % tests_product_ref)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    lines.append("")

    # Native targets
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append("\t\t%s /* Programma101 */ = {" % APP)
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"Programma101\" */;" % CONFIG_LIST_APP)
    lines.append("\t\t\tbuildPhases = (")
    lines.append("\t\t\t\t%s /* Sources */," % oid("phase-sources-app"))
    lines.append("\t\t\t\t%s /* Frameworks */," % fw_app)
    lines.append("\t\t\t\t%s /* Resources */," % oid("phase-resources-app"))
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Programma101;")
    lines.append("\t\t\tproductName = Programma101;")
    lines.append("\t\t\tproductReference = %s /* Programma101.app */;" % app_product_ref)
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Programma101Tests */ = {" % TESTS)
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"Programma101Tests\" */;" % CONFIG_LIST_TESTS)
    lines.append("\t\t\tbuildPhases = (")
    lines.append("\t\t\t\t%s /* Sources */," % oid("phase-sources-tests"))
    lines.append("\t\t\t\t%s /* Frameworks */," % fw_tests)
    lines.append("\t\t\t\t%s /* Resources */," % oid("phase-resources-tests"))
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Programma101Tests;")
    lines.append("\t\t\tproductName = Programma101Tests;")
    lines.append("\t\t\tproductReference = %s /* Programma101Tests.xctest */;" % tests_product_ref)
    lines.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")

    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append("\t\t%s /* Project object */ = {" % PROJECT_ID)
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1500;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append("\t\t\t\t\t%s = {" % APP)
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t\t%s = {" % TESTS)
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"Programma101\" */;" % CONFIG_LIST_PROJECT)
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t\tBase,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tmainGroup = %s;" % MAIN_GROUP)
    lines.append("\t\t\tproductRefGroup = %s /* Products */;" % PRODUCTS_GROUP)
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append("\t\t\t\t%s /* Programma101 */," % APP)
    lines.append("\t\t\t\t%s /* Programma101Tests */," % TESTS)
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    lines.append("")

    # Resources phases
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    res_app = oid("phase-resources-app")
    res_tests = oid("phase-resources-tests")
    lines.append("\t\t%s /* Resources */ = {" % res_app)
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t\t%s /* examples in Resources */," % examples_build)
    lines.append("\t\t\t\t%s /* AppIcon.icns in Resources */," % icon_build)
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Resources */ = {" % res_tests)
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")

    # Sources phases
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    src_app = oid("phase-sources-app")
    src_tests = oid("phase-sources-tests")
    lines.append("\t\t%s /* Sources */ = {" % src_app)
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for f in engine_files + app_files:
        if f.endswith(".m"):
            lines.append("\t\t\t\t%s /* %s in Sources */," % (buildfile(f, "app"), f))
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("\t\t%s /* Sources */ = {" % src_tests)
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for f in engine_files:
        if f.endswith(".m"):
            lines.append("\t\t\t\t%s /* %s in Sources */," % (buildfile(f, "tests"), f))
    lines.append("\t\t\t\t%s /* PCS101EngineTests.m in Sources */," % test_build)
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")

    # Build configurations
    def configuration(label, name, settings):
        cid = oid("config-" + label)
        lines.append("\t\t%s /* %s */ = {" % (cid, name))
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")
        for key in sorted(settings):
            value = settings[key]
            if isinstance(value, list):
                lines.append("\t\t\t\t%s = (" % key)
                for v in value:
                    lines.append("\t\t\t\t\t%s," % v)
                lines.append("\t\t\t\t);")
            else:
                lines.append("\t\t\t\t%s = %s;" % (key, value))
        lines.append("\t\t\t};")
        lines.append("\t\t\tname = %s;" % name)
        lines.append("\t\t};")
        return cid

    lines.append("/* Begin XCBuildConfiguration section */")
    common_debug = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": "\"gnu++20\"",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["\"DEBUG=1\"", "\"$(inherited)\""],
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "MACOSX_DEPLOYMENT_TARGET": "13.0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "macosx",
    }
    common_release = dict(common_debug)
    common_release.update({
        "DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS": "NO",
        "GCC_OPTIMIZATION_LEVEL": "s",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "ONLY_ACTIVE_ARCH": "NO",
    })
    common_release.pop("GCC_PREPROCESSOR_DEFINITIONS", None)
    common_release.pop("ENABLE_TESTABILITY", None)

    app_settings = {
        "CODE_SIGN_IDENTITY": "\"-\"",
        "CODE_SIGN_STYLE": "Automatic",
        "COMBINE_HIDPI_IMAGES": "YES",
        "HEADER_SEARCH_PATHS": ["\"$(inherited)\"", "\"$(SRCROOT)/Sources/Engine\"", "\"$(SRCROOT)/Sources/App\""],
        "INFOPLIST_FILE": "Sources/App/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": ["\"$(inherited)\"", "\"@executable_path/../Frameworks\""],
        "PRODUCT_BUNDLE_IDENTIFIER": "com.programma101.emulator",
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
    }
    test_settings = {
        "CODE_SIGN_IDENTITY": "\"-\"",
        "CODE_SIGN_STYLE": "Automatic",
        "ENABLE_TESTING_SEARCH_PATHS": "YES",
        "FRAMEWORK_SEARCH_PATHS": ["\"$(inherited)\"", "\"$(PLATFORM_DIR)/Developer/Library/Frameworks\""],
        "HEADER_SEARCH_PATHS": ["\"$(inherited)\"", "\"$(SRCROOT)/Sources/Engine\"", "\"$(SRCROOT)/Sources/App\""],
        "GENERATE_INFOPLIST_FILE": "YES",
        "OTHER_LDFLAGS": ["\"$(inherited)\"", "\"-framework\"", "XCTest"],
        "PRODUCT_BUNDLE_IDENTIFIER": "com.programma101.emulator.tests",
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "LD_RUNPATH_SEARCH_PATHS": ["\"$(inherited)\"", "\"@executable_path/../Frameworks\"", "\"@loader_path/../Frameworks\""],
    }

    dbg_proj = configuration("project-debug", "Debug", common_debug)
    rel_proj = configuration("project-release", "Release", common_release)
    dbg_app = configuration("app-debug", "Debug", app_settings)
    rel_app = configuration("app-release", "Release", app_settings)
    dbg_tests = configuration("tests-debug", "Debug", test_settings)
    rel_tests = configuration("tests-release", "Release", test_settings)
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")

    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    for lid, label, d, r in (
        (CONFIG_LIST_PROJECT, "PBXProject \"Programma101\"", dbg_proj, rel_proj),
        (CONFIG_LIST_APP, "PBXNativeTarget \"Programma101\"", dbg_app, rel_app),
        (CONFIG_LIST_TESTS, "PBXNativeTarget \"Programma101Tests\"", dbg_tests, rel_tests),
    ):
        lines.append("\t\t%s /* Build configuration list for %s */ = {" % (lid, label))
        lines.append("\t\t\tisa = XCConfigurationList;")
        lines.append("\t\t\tbuildConfigurations = (")
        lines.append("\t\t\t\t%s /* Debug */," % d)
        lines.append("\t\t\t\t%s /* Release */," % r)
        lines.append("\t\t\t);")
        lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
        lines.append("\t\t\tdefaultConfigurationName = Release;")
        lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("\t};")
    lines.append("\trootObject = %s /* Project object */;" % PROJECT_ID)
    lines.append("}")
    return "\n".join(lines) + "\n"

os.makedirs(os.path.join(PROJECT, "xcshareddata", "xcschemes"), exist_ok=True)
with open(os.path.join(PROJECT, "project.pbxproj"), "w") as f:
    f.write(pbx_object_lines())

scheme_app = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Programma101.app" BlueprintName = "Programma101" ReferencedContainer = "container:Programma101.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TESTS}" BuildableName = "Programma101Tests.xctest" BlueprintName = "Programma101Tests" ReferencedContainer = "container:Programma101.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Programma101.app" BlueprintName = "Programma101" ReferencedContainer = "container:Programma101.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Programma101.app" BlueprintName = "Programma101" ReferencedContainer = "container:Programma101.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
'''
with open(os.path.join(PROJECT, "xcshareddata", "xcschemes", "Programma101.xcscheme"), "w") as f:
    f.write(scheme_app)

scheme_tests = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "NO" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TESTS}" BuildableName = "Programma101Tests.xctest" BlueprintName = "Programma101Tests" ReferencedContainer = "container:Programma101.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TESTS}" BuildableName = "Programma101Tests.xctest" BlueprintName = "Programma101Tests" ReferencedContainer = "container:Programma101.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES"/>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"/>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
'''
with open(os.path.join(PROJECT, "xcshareddata", "xcschemes", "EngineTests.xcscheme"), "w") as f:
    f.write(scheme_tests)

print("wrote", PROJECT)
