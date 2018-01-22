#import "LuaScript.h"



// work around the Nil defination conflict of ObjC and LuaBridge
#ifdef Nil
#undef Nil
#define Nil LuaNil
#include "LuaBind.h"
#undef Nil
#define Nil nullptr
#endif

#import "TypefaceManager.h"

namespace elua {
    class Font {
    public:
        void setOpenTypeFeatures(const std::set<std::string> & otFeatures) {
            openTypeFeatures_ = otFeatures;
        }
        
        std::set<std::string> openTypeFeatures() const {
            return openTypeFeatures_;
        }
        
        
        Font & addOpenTypeFeature(const std::string & feature) {
            openTypeFeatures_.insert(feature);
            return *this;
        }
        
        Font & addOpenTypeFeatures(const std::initializer_list<std::string> & features) {
            for (const auto & f : features)
                openTypeFeatures_.insert(f);
            return * this;
        }
        
        
    public:
        std::string postscriptName;
        std::string version;
        std::string familyName;
        std::string styleName;
        std::string vender;
        
        std::string format;
        bool isOpenTypeVariation;
        bool isAdobeMultiMaster;
       
    private:
        std::set<std::string>  openTypeFeatures_;
    };
    
    void printMessage(const std::string & message) {
        NSLog(@"<Lua> %@", [NSString stringWithUTF8String:message.c_str()]);
    }
    
    std::string toStdString(NSString * str) {
        if (!str) return std::string();
        return std::string([str UTF8String]);
    }
    
    Font toLuaFont(TMTypeface * face) {
        Font f;
        f.familyName = toStdString(face.familyName);
        f.styleName = toStdString(face.styleName);
        f.vender = toStdString(face.attributes.vender);
        f.isOpenTypeVariation = face.attributes.isOpenTypeVariation;
        f.isAdobeMultiMaster = face.attributes.isAdobeMultiMaster;
        switch (face.attributes.format) {
            case TypefaceFormatTrueType: f.format = "TrueType"; break;
            case TypefaceFormatCFF: f.format = "CFF"; break;
            default: f.format = "Other";
        }
        return f;
    }
    
    void registerClasses(lua_State * L) {
        luabridge::getGlobalNamespace(L).
        beginNamespace("el")
        .addFunction("print", printMessage)
        .beginClass<Font>("Font")
        .addConstructor<void(*)(void)>()
        .addData("postscriptName", &Font::postscriptName, false)
        .addData("version", &Font::version, false)
        .addData("familyName", &Font::familyName, false)
        .addData("styleName", &Font::styleName, false)
        .addData("vender", &Font::vender, false)
        .addData("format", &Font::format, false)
        .addData("isOpenTypeVariation", &Font::isOpenTypeVariation, false)
        .addData("isAdobeMultiMaster", &Font::isAdobeMultiMaster, false)
        .addProperty("openTypeFeatures", &Font::openTypeFeatures)
        //.addProperty("name", &Font::familyName, &Font::setFamilyName)
        
        .endClass()
        .endNamespace();
    }
}

extern "C" {
    int luaScriptPrintMessage(lua_State *L) {
        const char * message = lua_tostring(L, -1);
        lua_getglobal(L, "__LuaScriptHost__");
        void * ptr  = lua_touserdata(L, -1);
        LuaScript * script = (__bridge LuaScript*)ptr;
        if (script.messageHandler) {
            script.messageHandler([NSString stringWithUTF8String:message]);
        }
        else {
            NSLog(@"<Lua> %@", [NSString stringWithUTF8String:message]);
        }
        return 0;
    }
}

@interface LuaScript() {
    lua_State *L;
}
-(BOOL)createState;
@end

@implementation LuaScript
-(instancetype)initWithFile:(NSString*)scriptFile {
    if ((self = [super init]) && [self createState]) {
        const char* utf8 = [scriptFile UTF8String];
        
        if (luaL_loadfile(L, utf8) || lua_pcall (L, 0, LUA_MULTRET, 0)) {
            lua_pop(L, 1); // failed to load script
        }
    }
    return self;
}

-(instancetype)initWithBuffer:(NSString*)script {
    if ((self = [super init]) && [self createState]) {
        const char* utf8 = [script UTF8String];
        int lua_error = LUA_OK;
        if ((lua_error = luaL_loadbufferx(L, utf8, strlen(utf8), "BUFFER-SCRIPT.LUA", NULL))
            || (lua_error = lua_pcall (L, 0, LUA_MULTRET, 0))) {
            lua_pop(L, 1); // failed to load script
        }
    }
    return self;
}

-(BOOL)createState {
    L = luaL_newstate();
    luaL_openlibs(L); // load Lua standard libraries.
    elua::registerClasses(L);
    
    lua_pushlightuserdata(L, (void*)CFBridgingRetain(self));
    lua_setglobal(L, "__LuaScriptHost__");
    lua_pushcfunction(L, luaScriptPrintMessage);
    lua_setglobal(L, "print");
    
    return YES;
}

-(BOOL)runWithFont:(TMTypeface *)font {
    
    luabridge::LuaRef fFilterFont = luabridge::getGlobal(L, "filterFont");
    if (fFilterFont.isFunction()) {
        try {
            elua::Font f = elua::toLuaFont(font);
            luabridge::LuaRef ref = fFilterFont(&f);
            bool ret = ref;
            return ret;
        }
        catch(const std::exception & ex) {
            NSLog(@"%@ %@", @"| exception", [NSString stringWithUTF8String:ex.what()]);
            return NO;
        }
    }
    else {
        NSLog(@"| failed to find function filterFont in script");
        return NO;
    }
    return YES;
}

@end
