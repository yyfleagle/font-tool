#include <algorithm>
#include <string>
#include <map>
#include <set>
#include <vector>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_CID_H
#include FT_SFNT_NAMES_H
#include FT_TRUETYPE_IDS_H
#include FT_TRUETYPE_TABLES_H
#include FT_SIZES_H

static int FT_DEFAULT_FONTSIZE = 24 * 4;
static int FT_DEFAULT_DPI      = 72;

#import "CharEncoding.h"
#import "Typeface.h"
#import "TypefaceManager.h"
#import "TypefaceNames.h"
#import "Shapper.h"

NSString * const TypefaceErrorDomain = @"TypefaceErrorDomain";


#pragma mark ###### GlyphLookupRequest #####
@implementation GlyphLookupRequest

+(instancetype)createRequestWithCharcode:(NSUInteger)charcode preferedBlock:(NSUInteger)preferedBlock {
    GlyphLookupRequest * request = [[GlyphLookupRequest alloc] init];
    request.lookupType = GlyphLookupByCharcode;
    request.lookupValue = [NSNumber numberWithUnsignedInteger:charcode];
    request.preferedBlock = preferedBlock;
    return request;
}

+(instancetype)createRequestWithId:(NSUInteger)gid preferedBlock:(NSUInteger)preferedBlock {
    GlyphLookupRequest * request = [[GlyphLookupRequest alloc] init];
    request.lookupType = GlyphLookupByGlyphIndex;
    request.lookupValue = [NSNumber numberWithUnsignedInteger:gid];
    request.preferedBlock = preferedBlock;
    return request;
}

+(instancetype)createRequestWithName:(NSString*)name preferedBlock:(NSUInteger)preferedBlock {
    GlyphLookupRequest * request = [[GlyphLookupRequest alloc] init];
    request.lookupType = GlyphLookupByName;
    request.lookupValue = name;
    request.preferedBlock = preferedBlock;
    return request;
}

+(instancetype)createRequestWithExpression:(NSString*)expression preferedBlock:(NSUInteger)preferedBlock {
    NSUInteger code = [CharEncoding charcodeOfString:expression];
    if (code != INVALID_CODE_POINT)
        return [GlyphLookupRequest createRequestWithCharcode:code preferedBlock:preferedBlock];
    
    code = [CharEncoding gidOfString:expression];
    if (code != INVALID_CODE_POINT)
        return [GlyphLookupRequest createRequestWithId:code preferedBlock:preferedBlock];
    
    return [GlyphLookupRequest createRequestWithName:expression preferedBlock:preferedBlock];
}

@end
#pragma mark ###### TypefaceTag #####

@implementation TypefaceTag

- (instancetype)initWithCode:(uint32_t)code {
    if (self = [super init]) {
        _code = code;
        _text = [TypefaceTag codeToText:code];
        
    }
    return self;
}

- (instancetype)initWithText:(NSString *)text {
    if (self = [super init]) {
        _text = text;
        _code = [TypefaceTag textToCode:text];
    }
    return self;
}

- (instancetype)copyWithZone:(nullable NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithCode:_code];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:self.code forKey:@"code"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _code = [aDecoder decodeInt32ForKey:@"code"];
        _text = [TypefaceTag codeToText:_code];
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if (self == other)
        return YES;
    if (![other isKindOfClass:[TypefaceTag class]])
        return NO;
    return [self isEqualToTag:other];
}

- (BOOL)isEqualToTag:(TypefaceTag*)other {
    return self.code == other.code;
}

- (NSUInteger)hash {
    return [_text hash];
}

- (NSString*)description {
    return _text;
}

- (NSComparisonResult)compare:(TypefaceTag*)other {
    return [self.text compare:other.text];
}

+ (NSString*)codeToText:(NSUInteger)code {
    char str[] = {
        (char)(code >> 24),
        (char)(code >> 16),
        (char)(code >> 8),
        (char)(code),
        0
    };
    
    return [NSString stringWithCString:str encoding:NSASCIIStringEncoding];
}

+ (NSUInteger)textToCode:(NSString*)text {
    if (text.length == 3)
        text = [NSString stringWithFormat:@"%@ ", text];
    
    if (text.length != 4)
        return -1;
    for (NSUInteger i = 0; i < text.length; ++ i) {
        unichar c = [text characterAtIndex:i];
        if (c > 126 || c < 32)
            return -1;
    }
//    NSAssert(text.length == 4, @"text must be 4 chars");
    
    return
    NSUInteger([text characterAtIndex:0] << 24) +
    NSUInteger([text characterAtIndex:1] << 16) +
    NSUInteger([text characterAtIndex:2] << 8) +
    NSUInteger([text characterAtIndex:3]);
};

+(TypefaceTag*)tagFromCode:(uint32_t)code {
    return [[TypefaceTag alloc] initWithCode:code];
}

@end

@implementation OpenTypeFeatureTag

-(id)copyWithZone:(NSZone *)zone {
    OpenTypeFeatureTag * copy = [super copyWithZone:zone];
    copy.isRequired = self.isRequired;
    return copy;
}

+(OpenTypeFeatureTag*)tagFromCode:(uint32_t)code {
    return [[OpenTypeFeatureTag alloc] initWithCode:code];
}

@end

#pragma mark ##### TypefaceGlyph #####
@implementation TypefaceGlyphcode

+(instancetype)glyphCodeWithGID:(NSUInteger)gid {
    TypefaceGlyphcode * gc = [[TypefaceGlyphcode alloc] init];
    gc.GID = gid;
    gc.isGID = YES;
    return gc;
}

+(instancetype)glyphCodeWithCharcode:(NSUInteger)charcode {
    TypefaceGlyphcode * gc = [[TypefaceGlyphcode alloc] init];
    gc.charcode = charcode;
    gc.isGID = NO;
    return gc;
}

@end


@interface TypefaceGlyphBlock ()
@property NSMutableArray<TypefaceGlyphcode*> * internalGlyphCodes;
@end

@implementation TypefaceGlyphBlock

- (id)init {
    if (self = [super init]) {
        self.internalGlyphCodes = [[NSMutableArray<TypefaceGlyphcode*> alloc] init];
    }
    return self;
}

- (TypefaceGlyphcode*)glyphCodeAtIndex:(NSUInteger)index {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSUInteger)numOfGlyphs {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return 0;
}

- (NSString*)name {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return 0;
}

@end


@implementation TypefaceGlyphRangeBlock

- (id)initWithFrom: (NSUInteger) from to:(NSUInteger)to isGID:(BOOL)isGID name:(NSString*)name {
    if (self = [super init]) {
        self.from = from;
        self.to = to;
        self.isGID = isGID;
        self.blockName = name;
    }
    return self;
}

- (NSString*)name {
    return self.blockName;
}

- (NSUInteger)numOfGlyphs {
    return self.to - self.from + 1;
}

-(TypefaceGlyphcode*)glyphCodeAtIndex:(NSUInteger)index {
    TypefaceGlyphcode * gc = [[TypefaceGlyphcode alloc] init];
    NSUInteger code = self.from + index;
    if (self.isGID)
        gc.GID = code;
    else
        gc.charcode = code;
    gc.isGID = self.isGID;
    return gc;
}


@end


@implementation TypefaceGlyph
- (NSString*)charcodeHex {
    NSString * hex = [CharEncoding hexForCharcode:self.charcode
                          unicodeFlavor:self.typeface.currentCMapIsUnicode];
    return hex? hex: UNDEFINED_UNICODE_CODEPOINT;
}
@end


#pragma mark ##### TypefaceGlyphImageCache #####

@interface TypefaceGlyphImageCacheItem : NSObject
@property  NSUInteger accessCount;
@property  NSImage * image;
@property  NSInteger imageOffsetX;
@property  NSInteger imageOffsetY;
@property  NSDate * lastAccess;

-(id)initWithImage:(NSImage*)image offsetX:(NSInteger)offsetX offsetY:(NSInteger)offsetY;
@end

@implementation TypefaceGlyphImageCacheItem

-(id)initWithImage:(NSImage *)image offsetX:(NSInteger)offsetX offsetY:(NSInteger)offsetY {
    if (self = [super init]) {
        self.image = image;
        self.imageOffsetX = offsetX;
        self.imageOffsetY = offsetY;
        self.accessCount = 1;
        self.lastAccess = [NSDate date];
    }
    return self;
}

typedef struct {
    NSUInteger gid;
    int score;
} TypefaceGlyphCacheScore;


int TypefaceGlyphCacheScoreCompare(const TypefaceGlyphCacheScore * a, const TypefaceGlyphCacheScore * b) {
    return (a->score - b->score);
}

@end

@interface TypefaceGlyphImageCache : NSObject
{
    NSMutableDictionary<NSNumber*, TypefaceGlyphImageCacheItem*> * cache;
}

@property (readonly) NSUInteger size;

-(id)initWithCacheSize:(NSUInteger)size;
-(TypefaceGlyphImageCacheItem*)cachedImageItemForGID:(NSUInteger)gid;
-(TypefaceGlyphImageCacheItem *)addCacheImage:(NSImage*)image offsetX:(NSInteger)offsetX offsetY:(NSInteger)offsetY forGID:(NSUInteger)gid;
-(void)invalidateImageCache;
@end

@implementation TypefaceGlyphImageCache

-(id)initWithCacheSize:(NSUInteger)size {
    if (self = [super init]) {
        _size = size;
        cache = [[NSMutableDictionary<NSNumber*, TypefaceGlyphImageCacheItem*> alloc] init];
    }
    return self;
}

-(TypefaceGlyphImageCacheItem*)cachedImageItemForGID:(NSUInteger)gid {
    TypefaceGlyphImageCacheItem * item = [cache objectForKey:[NSNumber numberWithUnsignedInteger:gid]];
    if (item) {
        ++ item.accessCount;
        item.lastAccess = [NSDate date];
    }
    return item;
}

-(TypefaceGlyphImageCacheItem *)addCacheImage:(NSImage*)image offsetX:(NSInteger)offsetX offsetY:(NSInteger)offsetY forGID:(NSUInteger)gid {
    TypefaceGlyphImageCacheItem * item = [[TypefaceGlyphImageCacheItem alloc] initWithImage:image offsetX:offsetX offsetY:offsetY];
    [cache setObject:item
              forKey:[NSNumber numberWithUnsignedInteger:gid]];
    return item;
}

-(void)invalidateImageCache {
    [cache removeAllObjects];
}

-(void)gc {
    if (cache.count < self.size * 1.5)
        return;
    
    TypefaceGlyphCacheScore * scoreItems = (TypefaceGlyphCacheScore*)malloc(sizeof(TypefaceGlyphCacheScore) * cache.count);
    
    __block NSUInteger index = 0;
    [cache enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, TypefaceGlyphImageCacheItem * _Nonnull obj, BOOL * _Nonnull stop) {
        int score = 0;
        if (key.unsignedIntegerValue == 0) // .nodef never removed
            score = INT_MAX;
        else
            score = obj.accessCount * 100 + obj.lastAccess.timeIntervalSinceNow;
        scoreItems[index].gid = key.unsignedIntegerValue;
        scoreItems[index].score = score;
        ++ index;
    }];
    
    qsort(scoreItems, cache.count, sizeof(TypefaceGlyphCacheScore), (int(*)(const void*, const void*))&TypefaceGlyphCacheScoreCompare);
    
    NSMutableArray<NSNumber*> * toRemove = [[NSMutableArray<NSNumber*> alloc] init];
    for (NSUInteger index = 0; index < (cache.count - self.size); ++ index) {
        [toRemove addObject:[NSNumber numberWithUnsignedInteger:scoreItems[index].gid]];
    }
    
    [cache removeObjectsForKeys:toRemove];
}
@end

#pragma mark #### TyepfaceGlyphNameCache ####

typedef struct {
    NSUInteger  charcode;
    NSUInteger  GID;
    std::string name;
} TypefaceGlyphName;

@interface TypefaceGlyphNameCache : NSObject {
    std::vector<TypefaceGlyphName> names;
    NSArray<NSString*>* allGlyphNames;
}
@property FT_Face face;
@property BOOL isUnicodeCMap;

- (instancetype)initWithFace:(FT_Face)face isUnicodeCMap:(BOOL)isUnicode;
- (void)rebuildFromFace:(FT_Face)face isUnicodeCMap:(BOOL)isUnicode;

- (TypefaceGlyphName*)lookupByGID:(NSUInteger)gid;
- (TypefaceGlyphName*)lookupByCharcode:(NSUInteger)charcode;
- (TypefaceGlyphName*)lookupByName:(const char *)name;

@end

@implementation TypefaceGlyphNameCache

- (instancetype)initWithFace:(FT_Face)face isUnicodeCMap:(BOOL)isUnicode {
    if (self = [super init]) {
        self.face = face;
        self.isUnicodeCMap = isUnicode;
    }
    return self;
}

- (void)rebuildFromFace:(FT_Face)face isUnicodeCMap:(BOOL)isUnicode {
    self.face = face;
    self.isUnicodeCMap = isUnicode;
    [self rebuild];
}

- (void)rebuild {
    names.clear();
    
    FT_ULong  charcode;
    FT_UInt   gindex;
    
    std::vector<bool> gidSet(self.face->num_glyphs);
    
    // sorted by charcode
    charcode = FT_Get_First_Char(self.face, &gindex);
    char glyphName[128] = {0};
    while (gindex) {
        charcode = FT_Get_Next_Char(self.face, charcode, &gindex);
        if (FT_Get_Glyph_Name(self.face, gindex, glyphName, 128)) {
            if (self.isUnicodeCMap)
                sprintf(glyphName, "U+%04lX", charcode);
            else
                sprintf(glyphName, "0x%04lX", charcode);
        }
        
        gidSet[gindex] = true;
        names.push_back({charcode, gindex, glyphName});
    }
    
    // incase gid is not found by FT_Get_First_Char / FT_Get_Next_Char
    for (size_t gid = 0; gid < gidSet.size(); ++ gid) {
        if (!gidSet[gid]) {
            if (FT_Get_Glyph_Name(self.face, gid, glyphName, 128))
                strcpy(glyphName, "<undefined>");
            
            names.push_back({INVALID_CODE_POINT, gid, glyphName});
        }
    }
}

- (void)checkForRebuild {
    if (names.empty()) {
        [self rebuild];
    }
}

- (NSArray<NSString*>*)getAllGlyphNames {
    if (allGlyphNames)
        return allGlyphNames;
    
    [self checkForRebuild];
    
    NSMutableArray<NSString*>* glyphNames = [[NSMutableArray<NSString*> alloc] init];
    for (TypefaceGlyphName & name : names)
        [glyphNames addObject:[NSString stringWithCString:name.name.c_str() encoding:NSASCIIStringEncoding]];
    
    [glyphNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    allGlyphNames = glyphNames;
    return glyphNames;
}

- (TypefaceGlyphName*)lookupByGID:(NSUInteger)gid {
    [self checkForRebuild];
    
    for (TypefaceGlyphName & name : names) {
        if (gid == name.GID)
            return &name;
    }
    return nil;
}

- (NSUInteger)lookupByGID:(NSUInteger)gid names:(TypefaceGlyphName**)outNames count:(NSUInteger*)inOutCount {
    [self checkForRebuild];
    
    NSUInteger ret = 0;
    for (TypefaceGlyphName & name : names) {
        if (inOutCount && *inOutCount == ret)
            break;
        
        if (gid == name.GID) {
            ++ ret;
            if (outNames && inOutCount)
                *(outNames++) = &name;
        }
    }
    
    if (inOutCount) *inOutCount = ret;
    return ret;
}

- (TypefaceGlyphName*)lookupByCharcode:(NSUInteger)charcode {
    [self checkForRebuild];
    
    // binary search
    auto itr = std::lower_bound(names.begin(), names.end(), charcode, [](const TypefaceGlyphName & name, NSUInteger code) {
        return name.charcode < code;
    });
    
    if (itr != names.end() && (charcode == itr->charcode))
        return &(*itr);
    else
        return nil;
}

- (TypefaceGlyphName*)lookupByName:(const char *)gname {
    [self checkForRebuild];
    
    for (TypefaceGlyphName & name : names) {
        if (gname == name.name)
            return &name;
    }
    return nil;
}


@end


#pragma mark ##### Typeface #####

@implementation TypefaceAttributes
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_openTypeScripts forKey:@"openTypeScripts"];
    [coder encodeObject:_openTypeLanguages forKey:@"openTypeLanguages"];
    [coder encodeObject:_openTypeFeatures forKey:@"openTypeFeatures"];
    [coder encodeInteger:_serifStyle forKey:@"serifStyle"];
    [coder encodeObject:_familyName forKey:@"familyName"];
    [coder encodeObject:_styleName forKey:@"styleName"];
    [coder encodeObject:_fullName forKey:@"fullName"];
    [coder encodeObject:_preferedLocalizedFamilyName forKey:@"preferedLocalizedFamilyName"];
    [coder encodeObject:_preferedLocalizedStyleName forKey:@"preferedLocalizedStyleName"];
    [coder encodeObject:_preferedLocalizedFullName forKey:@"preferedLocalizedFullName"];
    [coder encodeObject:_localizedFamilyNames forKey:@"localizedFamilyNames"];
    [coder encodeObject:_localizedStyleNames forKey:@"localizedStyleNames"];
    [coder encodeObject:_localizedFullNames forKey:@"localizedFullNames"];
    [coder encodeObject:_designLanguages forKey:@"designLanguages"];
    [coder encodeObject:_vender forKey:@"vender"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _openTypeScripts = [decoder decodeObjectForKey:@"openTypeScripts"];
        _openTypeLanguages = [decoder decodeObjectForKey:@"openTypeLanguages"];
        _openTypeFeatures = [decoder decodeObjectForKey:@"openTypeFeatures"];
        _serifStyle = (TypefaceSerifStyle)[decoder decodeIntegerForKey:@"serifStyle"];
        _familyName = [decoder decodeObjectForKey:@"familyName"];
        _styleName = [decoder decodeObjectForKey:@"styleName"];
        _fullName = [decoder decodeObjectForKey:@"fullName"];
        _preferedLocalizedFamilyName = [decoder decodeObjectForKey:@"preferedLocalizedFamilyName"];
        _preferedLocalizedStyleName = [decoder decodeObjectForKey:@"preferedLocalizedStyleName"];
        _preferedLocalizedFullName = [decoder decodeObjectForKey:@"preferedLocalizedFullName"];
        _localizedFamilyNames = [decoder decodeObjectForKey:@"localizedFamilyNames"];
        _localizedStyleNames = [decoder decodeObjectForKey:@"localizedStyleNames"];
        _localizedFullNames = [decoder decodeObjectForKey:@"localizedFullNames"];
        _designLanguages = [decoder decodeObjectForKey:@"designLanguages"];
        _vender = [decoder decodeObjectForKey:@"vender"];
    }
    return self;
}

@end

@interface TypefaceDescriptor ()
- (id)initWithFamily:(NSString*)family style:(NSString*)style;
- (id)initWithFileURL:(NSURL*)url faceIndex:(NSInteger)faceIndex;

@end

@implementation TypefaceDescriptor

- (id)initWithFamily:(NSString*)family style:(NSString*)style {
    if (self = [super init]) {
        self.family = family;
        self.style = style;
        self.faceIndex = INVALID_FACE_INDEX;
    }
    return self;
}


- (id)initWithFileURL:(NSURL*)url faceIndex:(NSInteger)faceIndex {
    if (self = [super init]) {
        self.fileURL = url;
        self.faceIndex = faceIndex;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.isNameDescriptor) {
        [coder encodeObject:self.family forKey:@"family"];
        [coder encodeObject:self.style forKey:@"style"];
    }
    else {
        [coder encodeObject:self.fileURL forKey:@"fileURL"];
        [coder encodeInteger:self.faceIndex forKey:@"faceIndex"];
    }
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _family = [decoder decodeObjectForKey:@"family"];
        _style = [decoder decodeObjectForKey:@"style"];
        if (!_family || !_style)
        {
            _family = nil;
            _style = nil;
            _fileURL = [decoder decodeObjectForKey:@"fileURL"];
            _faceIndex = [decoder decodeIntegerForKey:@"faceIndex"];
        }
        else {
            _faceIndex = INVALID_FACE_INDEX;
        }
    }
    return self;
}

- (BOOL)isFileDescriptor {
    return self.faceIndex != INVALID_FACE_INDEX;
}

- (BOOL)isNameDescriptor {
    return ![self isFileDescriptor];
}

- (id)copyWithZone:(nullable NSZone *)zone {
    TypefaceDescriptor * copy = [[[self class] allocWithZone:zone] init];
    copy.fileURL = [self.fileURL copyWithZone:zone];
    copy.faceIndex = self.faceIndex;
    copy.family = [self.family copyWithZone:zone];
    copy.style = [self.style copyWithZone:zone];
    return copy;
}

- (BOOL)isEqual:(id)other {
    if (self == other)
        return YES;
    if (![other isKindOfClass:[TypefaceDescriptor class]])
        return NO;
    TypefaceDescriptor * d = (TypefaceDescriptor*)other;
    return [self isEqualToDescriptor:d];
}

- (BOOL)isEqualToDescriptor:(TypefaceDescriptor*)other {
    if (self.isNameDescriptor)
        return [self.family isEqualToString:other.family] && [self.style isEqualToString:other.style];
    else
        return [self.fileURL isEqualTo:other.fileURL] && (self.faceIndex == other.faceIndex);
}

- (NSUInteger)hash {
    if (self.isNameDescriptor)
        return [[NSString stringWithFormat:@"%@ %@", self.family, self.style] hash];
    else
        return [self.fileURL hash] + self.faceIndex;
}

- (NSString *)description {
    if (self.isNameDescriptor)
        return [NSString stringWithFormat:@"%@ %@", self.family, self.style];
    else
        return [NSString stringWithFormat:@"%@ %ld", self.fileURL, self.faceIndex];
}

- (NSComparisonResult)compare:(TypefaceDescriptor*)other {
    if (self.isNameDescriptor) {
        NSComparisonResult result = [self.family compare:other.family];
        if (result != NSOrderedSame)
            result = [self.style compare:other.style];
        return result;
    }
    else {
        NSComparisonResult result = [self.fileURL.absoluteString compare:other.fileURL.absoluteString];
        if (result != NSOrderedSame) {
            if (self.faceIndex > other.faceIndex)
                return NSOrderedDescending;
            else if (self.faceIndex < other.faceIndex)
                return NSOrderedDescending;
            else
                return NSOrderedSame;
        }
        return result;
    }
}

+ (instancetype) descriptorWithFamily:(NSString*)family style:(NSString*)style {
    return [[TypefaceDescriptor alloc] initWithFamily:family style:style];
}

+ (instancetype) descriptorWithFileURL:(NSURL*)fileURL faceIndex:(NSUInteger)index {
    return [[TypefaceDescriptor alloc] initWithFileURL:fileURL faceIndex:index];
}

+ (instancetype) descriptorWithFilePath:(NSString*)filePath faceIndex:(NSUInteger)index {
    return [[TypefaceDescriptor alloc] initWithFileURL:[NSURL fileURLWithPath:filePath] faceIndex:index];
}

@end

@interface Typeface() {
    FT_Face  face;
    NSMutableArray<TypefaceCMap*> * cmaps;
    TypefaceGlyphImageCache * imageCache;
    
    TypefaceGlyphNameCache * glyphNameCache;
    NSSet<OpenTypeFeatureTag*> * openTypeFeatureTags;
}
-(NSUInteger)numOfGlyphs;

@end

@implementation Typeface

@synthesize fontSize = _fontSize;
@synthesize attributes = _attributes;
@synthesize glyphNames = _glyphNames;


-(id) initWithOpaqueFace:(OpaqueFTFace)opaqueFace {
    if (self = [super init]) {
        face = (FT_Face)opaqueFace;
        FT_Reference_Face(face);
        
        if (![self setupTypeface:nil])
            return nil;
    }
    return self;
}

-(id) initWithContentOfFile:(NSURL*)url faceIndex:(NSUInteger)index {
    if (self = [super init]) {
        FT_New_Face(self.ftLib, [url.path UTF8String], index, &face);
        
        if (![self setupTypeface:url]) {
            FT_Done_Face(face);
            return nil;
        }
    }
    return self;
}

-(id) initWithDescriptor:(TypefaceDescriptor*)descriptor {
    if (self = [super init]) {
        if (descriptor.isNameDescriptor)
            descriptor = [[TypefaceManager defaultManager] fileDescriptorFromNameDescriptor:descriptor];
        if (!descriptor)
            return nil;
        
        FT_New_Face(self.ftLib, [descriptor.fileURL.path UTF8String], descriptor.faceIndex, &face);
        
        if (![self setupTypeface:descriptor.fileURL]) {
            FT_Done_Face(face);
            return nil;
        }
    }
    return self;
}

- (FT_Library)ftLib {
    return (FT_Library) [[TypefaceManager defaultManager] ftLib];
}

- (BOOL) setupTypeface:(NSURL*)fileURL {
    cmaps = [[NSMutableArray<TypefaceCMap*> alloc] init];
    imageCache = [[TypefaceGlyphImageCache alloc] initWithCacheSize:500];
    
    // setup cmap
    // Freetype will try to select the unicode cmap on creating face, but some fonts
    // doesn't contains unicode cmap
    if (!face->charmap) {
        if (face->num_charmaps) {
            FT_Set_Charmap(face, face->charmaps[0]);
        }
        else {
            return NO;
        }
    }
    
    // read all cmaps
    for (FT_Int i = 0; i < face->num_charmaps; ++ i) {
        FT_CharMap cm = face->charmaps[i];
        [cmaps addObject:[[TypefaceCMap alloc] initWithPlatformId:cm->platform_id encodingId:cm->encoding_id  ofFace:self]];
    }
    
    self.fontSize = FT_DEFAULT_FONTSIZE;
    _dpi = FT_DEFAULT_DPI;
    
    // info
    _familyName = [NSString stringWithUTF8String:face->family_name];
    _styleName = [NSString stringWithUTF8String:face->style_name];
    _fileURL = fileURL;
    _faceIndex = face->face_index;
    
    // build glyph name cache
    glyphNameCache = [[TypefaceGlyphNameCache alloc] initWithFace:face
                                                    isUnicodeCMap:self.currentCMap.isUnicode];
    return YES;
}

- (void)setFontSize:(CGFloat)fontSize {
    _fontSize = fontSize;
    
    // set size
    const FT_Short pt = self.fontSize;
    FT_Set_Char_Size(face,
                     0,     // same as height
                     pt << 6,
                     self.dpi,
                     self.dpi);
    
    [imageCache invalidateImageCache];
}

- (CGFloat)fontSize {
    return _fontSize;
}

- (void)setPixelSize:(NSUInteger) px {
    self.fontSize = px * 72.0 / self.dpi;
}

- (NSUInteger)getUPEM {
    return face->units_per_EM;
}

- (NSInteger)getAscender {
    return face->ascender;
}

- (NSInteger)getDescender {
    return face->descender;
}

- (CGRect)getBBox {
    FT_BBox box = face->bbox;
    return CGRectMake(box.xMin, box.yMin, box.xMax - box.xMin, box.yMax - box.yMin);
}

- (NSUInteger)getNumberOfGlyphs {
    return face->num_glyphs;
}

- (OpaqueFTFace)nativeFace {
    return face;
}

#pragma mark *** Getters ***
- (NSArray<TypefaceCMap*>*)cmaps {
    return cmaps;
}

- (TypefaceCMap*)currentCMap {
    return [cmaps objectAtIndex:self.currentCMapIndex];
}

- (NSUInteger)currentCMapIndex {
    FT_CharMap curr = face->charmap;
    for (FT_Int i = 0; i < face->num_charmaps; ++ i) {
        FT_CharMap cm = face->charmaps[i];
        if (cm->platform_id == curr->platform_id && cm->encoding_id == curr->encoding_id)
            return i;
    }
    return -1;
}

- (BOOL)currentCMapIsUnicode {
    return [self currentCMap].isUnicode;
}


#pragma mark *** Attributes & Names ***

- (TypefaceAttributes*)getAttributes {
    if (!_attributes) {
        _attributes = [[TypefaceAttributes alloc] init];
        
        // OT features
        Shapper * shapper = [[Shapper alloc] initWithTypeface:self];
        _attributes.openTypeScripts = [shapper allScripts];
        _attributes.openTypeLanguages = [shapper allLanguages];
        _attributes.openTypeFeatures = [shapper allFeatures];
        
        // format
        const char * format = FT_Get_Font_Format(face);
        if (!strcmp(format, "TrueType"))
            _attributes.format = TypefaceFormatTrueType;
        else if (!strcmp(format, "CFF"))
            _attributes.format = TypefaceFormatCFF;
        else
            _attributes.format = TypefaceFormatOther;
        
        // Names
        [self loadNamesForAttributes:_attributes];
        
        // Serif
        TT_OS2 * os2 = (TT_OS2*)FT_Get_Sfnt_Table(face,  FT_SFNT_OS2);
        if (os2) {
            unsigned char familyClass = ((os2->sFamilyClass & 0xFF00) >> 8);
            //unsigned char subFamilyClass = (os2->sFamilyClass & 0x00FF);
            if (familyClass >= 1 && familyClass <= 7)
                _attributes.serifStyle = TypefaceSerifStyleSerif;
            else if (familyClass == 8)
                _attributes.serifStyle = TypefaceSerifStyleSansSerif;
            else
                _attributes.serifStyle = TypefaceSerifStyleUndefined;
        }
        else {
            _attributes.serifStyle = TypefaceSerifStyleUndefined;
        }
    }
    return _attributes;
}


- (NSString*)getPreferedLocalizedFamilyName {
    return self.attributes.preferedLocalizedFamilyName;
}

- (NSString*)getPreferedLocalizedStyleName {
    
    return self.attributes.preferedLocalizedStyleName;
}

- (NSString*)getPreferedLocalizedFullName {
    
    return self.attributes.preferedLocalizedFullName;
}

- (void)loadNamesForAttributes:(TypefaceAttributes*)attributes {
    FT_Error error = 0;
    FT_UInt count = FT_Get_Sfnt_Name_Count(face);
    
    static const FT_UShort nameIDOrder[] = {
        TT_NAME_ID_WWS_FAMILY,
        TT_NAME_ID_PREFERRED_FAMILY,
        TT_NAME_ID_FONT_FAMILY,
        TT_NAME_ID_MAC_FULL_NAME,
        TT_NAME_ID_FULL_NAME,
        TT_NAME_ID_WWS_SUBFAMILY,
        TT_NAME_ID_PREFERRED_SUBFAMILY,
        TT_NAME_ID_FONT_SUBFAMILY,
        TT_NAME_ID_TRADEMARK,
        TT_NAME_ID_MANUFACTURER,
    };
    
    NSMutableDictionary<NSString*, NSString*> *localizedFamilyNames = [[NSMutableDictionary<NSString*, NSString*> alloc] init];
    NSMutableDictionary<NSString*, NSString*> *localizedStyleNames = [[NSMutableDictionary<NSString*, NSString*> alloc] init];
    NSMutableDictionary<NSString*, NSString*> *localizedFullNames = [[NSMutableDictionary<NSString*, NSString*> alloc] init];

    for (FT_UShort nameId : nameIDOrder) {
        for (FT_UInt i = 0; i < count; ++ i) {
            FT_SfntName sfntName;
            error = FT_Get_Sfnt_Name(face, i, &sfntName);
            if (error)
                continue;
            
            if (nameId != sfntName.name_id)
                continue;
            
            NSString * lang = SFNTNameGetLanguage(&sfntName, face);
            if(!lang)
                lang = @"en";
            switch(nameId) {
                case TT_NAME_ID_WWS_FAMILY:
                case TT_NAME_ID_PREFERRED_FAMILY:
                case TT_NAME_ID_FONT_FAMILY:
                    if (![localizedFamilyNames objectForKey:lang])
                        [localizedFamilyNames setObject:SFNTNameGetString(&sfntName) forKey:lang];
                    break;
                    
                case TT_NAME_ID_WWS_SUBFAMILY:
                case TT_NAME_ID_PREFERRED_SUBFAMILY:
                case TT_NAME_ID_FONT_SUBFAMILY:
                    if (![localizedStyleNames objectForKey:lang])
                        [localizedStyleNames setObject:SFNTNameGetString(&sfntName) forKey:lang];
                    break;
                    
                case TT_NAME_ID_MAC_FULL_NAME:
                case TT_NAME_ID_FULL_NAME:
                    if (![localizedFullNames objectForKey:lang])
                        [localizedFullNames setObject:SFNTNameGetString(&sfntName) forKey:lang];
                    break;
            }
            
        }
    }
    
    attributes.familyName = [NSString stringWithUTF8String:face->family_name];
    attributes.styleName = [NSString stringWithUTF8String:face->style_name];
 
#if DEBUG
    BOOL foundFamily = NO, foundStyle = NO;
    for (NSString * lang in localizedFamilyNames) {
        if ([[localizedFamilyNames objectForKey:lang] isEqualToString:attributes.familyName]) {
            foundFamily = YES;
            //NSLog(@"%@ %@", lang, attributes.familyName);
            break;
        }
    }
    for (NSString * lang in localizedStyleNames) {
        if ([[localizedStyleNames objectForKey:lang] isEqualToString:attributes.styleName]) {
            foundStyle = YES;
            break;
        }
    }
    
    if (!(foundFamily && foundStyle) && ![attributes.familyName isEqualToString:@"System Font"])
        NSLog(@"exepct family and style from name table");
#endif
    
    // name lanuages
    NSMutableSet<NSString*> * languages = [[NSMutableSet<NSString*> alloc] init];
    for (NSString * lang in localizedFamilyNames)
        [languages addObject:lang];
    for (NSString * lang in localizedStyleNames)
        [languages addObject:lang];

    attributes.designLanguages = [languages allObjects];
    
    // localized names
    attributes.localizedFamilyNames = localizedFamilyNames;
    attributes.localizedStyleNames = localizedStyleNames;
    attributes.localizedFullNames = localizedFullNames;
    
    NSString * (^searchLocalizedName)(NSDictionary<NSString*, NSString*> *, NSString *, NSString**) = ^(NSDictionary<NSString*, NSString*> * nameDict, NSString * preferedLang, NSString** outLang) {
        NSString * name = nil;
        if (preferedLang)
            name = [nameDict objectForKey:preferedLang];
        
        if (name) {
            if (outLang) *outLang = preferedLang;
            return name;
        }
        
        NSArray<NSString*> * langSearchOrder = @[@"zh-cn", @"zh-hk", @"zh-tw", @"zh-sg", @"zh", @"ja", @"ko", @"en"];
        for (NSString * lang in langSearchOrder) {
            name = [nameDict objectForKey:lang];
            if (name) {
                if (outLang) *outLang = lang;
                return name;
            }
        }
        return (NSString *)nil;
    };
    
    NSString * familyLang = nil;
    attributes.preferedLocalizedFamilyName = searchLocalizedName(attributes.localizedFamilyNames, nil, &familyLang);
    attributes.preferedLocalizedStyleName = searchLocalizedName(attributes.localizedStyleNames, familyLang, nil);
    attributes.preferedLocalizedFullName = searchLocalizedName(attributes.localizedFullNames, familyLang, nil);
    
    if (!attributes.preferedLocalizedFamilyName)
        attributes.preferedLocalizedFamilyName = attributes.familyName;
    if (!attributes.preferedLocalizedStyleName)
        attributes.preferedLocalizedStyleName = attributes.styleName;
    if (!attributes.preferedLocalizedFullName)
        attributes.preferedLocalizedFullName = [NSString stringWithFormat:@"%@ %@", attributes.preferedLocalizedFamilyName, attributes.preferedLocalizedStyleName];
}


#pragma mark *** CMaps ***

- (TypefaceCMap*)getCMapAtIndex:(NSUInteger)index {
    return [cmaps objectAtIndex:index];
}

- (TypefaceCMap*)selectCMap:(TypefaceCMap*)cmap {
    for (FT_Int i = 0; i < face->num_charmaps; ++ i) {
        FT_CharMap cm = face->charmaps[i];
        if (cm->platform_id == cmap.platformId && cm->encoding_id == cmap.encodingId) {
            FT_Set_Charmap(face, cm);
        }
    }
    [glyphNameCache rebuildFromFace:face isUnicodeCMap:self.currentCMap.isUnicode];
    return self.currentCMap;
}

- (TypefaceCMap*)selectCMapAtIndex:(NSUInteger)index {
    return [self selectCMap:[self getCMapAtIndex:index]];
}

#pragma mark *** Glyph Loading ***

- (NSArray<NSString*> *)glyphNames {
    if (!_glyphNames) {
        _glyphNames = [glyphNameCache getAllGlyphNames];
    }
    return _glyphNames;
}


-(NSUInteger)numOfGlyphs {
    return face->num_glyphs;
}

- (TypefaceGlyph*)loadGlyph:(TypefaceGlyphcode *)gc {
    uint32_t gid = gc.GID;
    if (!gc.isGID)
        gid = FT_Get_Char_Index(face, gc.charcode);
    
    // glyph image
    TypefaceGlyphImageCacheItem * item = [imageCache cachedImageItemForGID:gid];
    if (!item) {
        FT_Load_Glyph(face, gid, FT_LOAD_RENDER);
        FT_GlyphSlot slot = face->glyph;
        NSImage * image = [self imageFromBitmap:slot->bitmap];
        NSInteger offsetX = slot->bitmap_left;
        NSInteger offsetY = slot->bitmap_top - image.size.height;
        item = [imageCache addCacheImage:image offsetX:offsetX offsetY:offsetY forGID:gid];
        
        [imageCache gc];
    }
    
    TypefaceGlyph * g = [[TypefaceGlyph alloc] init];
    
    g.GID = gid;
    g.image = item.image;
    g.imageOffsetX = item.imageOffsetX;
    g.imageOffsetY = item.imageOffsetY;
    g.imageFontSize = _fontSize;
    
    // glyph name and charcodes
    NSUInteger gnameCount = [glyphNameCache lookupByGID:gid names:nil count:nil];
    TypefaceGlyphName ** gnames = (TypefaceGlyphName**)malloc(sizeof(TypefaceGlyphName *) * gnameCount);
    [glyphNameCache lookupByGID:gid names:gnames count:&gnameCount];
    
    NSMutableArray<NSNumber*> * charcodes = [[NSMutableArray<NSNumber*> alloc] init];
    for (NSUInteger index = 0; index < gnameCount; ++ index) {
        TypefaceGlyphName * gname = *(gnames + index);
        if (!g.name)
            g.name = [NSString stringWithUTF8String:gname->name.c_str()];
        
        [charcodes addObject:[NSNumber numberWithUnsignedInteger:gname->charcode]];
    }
    if (!g.name && !gc.isGID)
        g.name = [self composeNameForGlyph:gid code:gc.charcode isUnicode:[self currentCMapIsUnicode]];
    if (!g.name)
        g.name = @"nil";
    
    g.charcodes = charcodes;
    if (gc.isGID) {
        // take the first one
        if (charcodes.count)
            g.charcode = [charcodes objectAtIndex:0].unsignedIntegerValue;
        else
            g.charcode = INVALID_CODE_POINT;
    }
    else {
        g.charcode = gc.charcode;
    }
    free(gnames);
    
#if 0
    TypefaceGlyphName * gname = nil;
    if (gc.isGID)
        gname = [glyphNameCache lookupByGID:gc.GID];
    else
        gname = [glyphNameCache lookupByCharcode:gc.charcode];
    
    if (gname) {
        g.name = [NSString stringWithUTF8String:gname->name.c_str()];//[self composeNameForGlyph:gid code:gc.charcode isUnicode:g.isUnicode];
        g.charcode = gc.isGID? gname->charcode: gc.charcode;
    }
    else {
        g.name = [self composeNameForGlyph:gid code:gc.charcode isUnicode:[self currentCMapIsUnicode]];
        g.charcode = gc.charcode;
    }
#endif
    
    // glyph metrics
    FT_Load_Glyph(face, gid, FT_LOAD_NO_SCALE);
    FT_Glyph_Metrics * metrics = &face->glyph->metrics;
    g.width = metrics->width;
    g.height = metrics->height;
    g.horiBearingX = metrics->horiBearingX;
    g.horiBearingY = metrics->horiBearingY;
    g.horiAdvance = metrics->horiAdvance;
    g.vertBearingX = metrics->vertBearingX;
    g.vertBearingY = metrics->vertBearingY;
    g.vertAdvance = metrics->vertAdvance;
    
    g.typeface = self;
    return g;
}

- (TypefaceGlyph*)loadGlyph:(TypefaceGlyphcode*)gc size:(CGFloat)fontSize {
    if (fontSize == self.fontSize)
        return [self loadGlyph:gc];
    
    FT_Size defaultSize = face->size;
    
    uint32_t gid = gc.GID;
    if (!gc.isGID)
        gid = FT_Get_Char_Index(face, gc.charcode);
    
    // select the new fontsize
    FT_Size newSize;
    FT_New_Size(face, &newSize);
    FT_Activate_Size(newSize);
    
    const FT_Short pt = fontSize;
    FT_Set_Char_Size(face,
                     0,     // same as height
                     pt << 6,
                     self.dpi,
                     self.dpi);
    
    TypefaceGlyph * g = [[TypefaceGlyph alloc] init];

    {
        FT_Load_Glyph(face, gid, FT_LOAD_RENDER);
        FT_GlyphSlot slot = face->glyph;
        NSImage * image = [self imageFromBitmap:slot->bitmap];
        NSInteger offsetX = slot->bitmap_left;
        NSInteger offsetY = slot->bitmap_top - image.size.height;
        
        g.GID = gid;
        g.image = image;
        g.imageOffsetX = offsetX;
        g.imageOffsetY = offsetY;
        g.imageFontSize = fontSize;
    }
    
    FT_Activate_Size(defaultSize);
    FT_Done_Size(newSize);
    
    // Load the glyph of default size, to get metrics/names
    TypefaceGlyphcode * code = [[TypefaceGlyphcode alloc] init];
    code.isGID = YES;
    code.GID = gid;
    TypefaceGlyph * defaultGlyph = [self loadGlyph:code];
    
    g.name = defaultGlyph.name;
    g.charcode = gc.isGID? defaultGlyph.charcode : gc.charcode;
    g.charcodes = defaultGlyph.charcodes;
    g.width = defaultGlyph.width;
    g.height = defaultGlyph.height;
    g.horiBearingX = defaultGlyph.horiBearingX;
    g.horiBearingY = defaultGlyph.horiBearingY;
    g.horiAdvance = defaultGlyph.horiAdvance;
    g.vertBearingX = defaultGlyph.vertBearingX;
    g.vertBearingY = defaultGlyph.vertBearingY;
    g.vertAdvance = defaultGlyph.vertAdvance;
    
    g.typeface = self;
    
    return g;
}

- (NSImage*)imageFromBitmap:(FT_Bitmap) bm {
    if (!bm.rows || !bm.width)
        return nil;
    
    NSImage * image = nil;
    
    if (bm.pixel_mode == FT_PIXEL_MODE_GRAY) {
        NSAssert(bm.pixel_mode == FT_PIXEL_MODE_GRAY, @"Grayscale Font only");
        
        size_t length = bm.rows * bm.pitch;
        unsigned char * planes[5] = {NULL};
        NSBitmapImageRep * imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
                                                                              pixelsWide:bm.width
                                                                              pixelsHigh:bm.rows
                                                                           bitsPerSample:8
                                                                         samplesPerPixel:2
                                                                                hasAlpha:YES
                                                                                isPlanar:YES
                                                                          colorSpaceName:NSDeviceWhiteColorSpace
                                                                             bytesPerRow:bm.pitch
                                                                            bitsPerPixel:8];
        
        [imageRep getBitmapDataPlanes:planes];
        memset(planes[0], 0, length); // black plane
        memcpy(planes[1], bm.buffer, length);  // alpha plane
        
        NSSize imageSize = NSMakeSize(CGImageGetWidth([imageRep CGImage]), CGImageGetHeight([imageRep CGImage]));
        image = [[NSImage alloc] initWithSize:imageSize];
        [image addRepresentation:imageRep];
    }
    return image;
}

- (NSImage*)loadGlyphImageFromSlot:(FT_GlyphSlot)slot {
    NSImage * glyphImage = [self imageFromBitmap:slot->bitmap];

    return glyphImage;
}


#pragma mark *** Glyph Lookup ***
- (void)lookupGlyph:(GlyphLookupRequest *)request completeHandler:(void (^)(NSUInteger blockIndex, NSUInteger itemIndex, NSError *error))handler {
    GlyphLookupType type = request.lookupType;
    NSUInteger preferedBlockIndex = request.preferedBlock;
    
    TypefaceCMap * currCMap = [self currentCMap];
    NSError * error = nil;
    if (type == GlyphLookupByCharcode) {
        NSUInteger code = [request.lookupValue unsignedIntegerValue];
        
        if (code == INVALID_CODE_POINT) {
            error = [NSError errorWithDomain:TypefaceErrorDomain code:INVALID_CODE_POINT userInfo:nil];
            handler(0, 0, error);
        }
        else {
            if (preferedBlockIndex == 0) { // 'All Glyph' block
                TypefaceGlyphName * tgn = [glyphNameCache lookupByCharcode:code];
                if (tgn) {
                    return [self lookupGlyph:[GlyphLookupRequest createRequestWithId:tgn->GID preferedBlock:preferedBlockIndex]
                             completeHandler:handler];
                }
            }
            
            NSUInteger blockIndex = INVALID_CODE_POINT;
            NSUInteger itemIndex = INVALID_CODE_POINT;
            std::vector<NSUInteger> searchBlocks;
            searchBlocks.push_back(preferedBlockIndex);
            for (NSUInteger i = 2; i < currCMap.glyphBlocks.count; ++ i)
                searchBlocks.push_back(i);
            searchBlocks.push_back(1); // unicode full
            
            for (NSUInteger i : searchBlocks) {
                if (i >= currCMap.glyphBlocks.count)
                    continue;
                TypefaceGlyphRangeBlock * block = (TypefaceGlyphRangeBlock*)[currCMap.glyphBlocks objectAtIndex:i];
                if (block.from <= code && code <= block.to) {
                    blockIndex = i;
                    itemIndex = code - block.from;
                    break;
                }
            }
            
            if (blockIndex == INVALID_CODE_POINT || itemIndex == INVALID_CODE_POINT) {
                // let's fallback to 'All Glyph' block
                TypefaceGlyphName * tgn = [glyphNameCache lookupByCharcode:code];
                if (tgn) {
                    return [self lookupGlyph:[GlyphLookupRequest createRequestWithId:tgn->GID preferedBlock:preferedBlockIndex]
                             completeHandler:handler];
                }
                
                error = [NSError errorWithDomain:TypefaceErrorDomain code:INVALID_CODE_POINT userInfo:nil];
            }
            
            handler(blockIndex, itemIndex, error);
        }
    }
    else if (type == GlyphLookupByGlyphIndex) {
        NSUInteger gid = [request.lookupValue unsignedIntegerValue];
        if (preferedBlockIndex != 0) {
            TypefaceGlyphName * tgn = [glyphNameCache lookupByGID:gid];
            if (tgn && tgn->charcode != INVALID_CODE_POINT) {
                return [self lookupGlyph:[GlyphLookupRequest createRequestWithCharcode:tgn->charcode preferedBlock:preferedBlockIndex]
                         completeHandler:handler];
            }
        }
        
        // always goto the 'All Glyph' block
        if (gid == INVALID_CODE_POINT)
            error = [NSError errorWithDomain:TypefaceErrorDomain code:INVALID_CODE_POINT userInfo:nil];
        
        handler(0, gid, error);
    }
    else if (type == GlyphLookupByName) {
        TypefaceGlyphName * tgn = [glyphNameCache lookupByName:[(NSString*)(request.lookupValue) UTF8String]];
        if (tgn) {
            if (tgn->charcode == INVALID_CODE_POINT) {
                return [self lookupGlyph:[GlyphLookupRequest createRequestWithId:tgn->GID preferedBlock:preferedBlockIndex]
                         completeHandler:handler];
            }
            else  {
                if (preferedBlockIndex == 0) {
                    return [self lookupGlyph:[GlyphLookupRequest createRequestWithId:tgn->GID preferedBlock:preferedBlockIndex]
                             completeHandler:handler];
                }
                else {
                    return [self lookupGlyph:[GlyphLookupRequest createRequestWithCharcode:tgn->charcode preferedBlock:preferedBlockIndex]
                             completeHandler:handler];
                }
            }
        }
        else {
            error = [NSError errorWithDomain:TypefaceErrorDomain code:INVALID_CODE_POINT userInfo:nil];
            handler(INVALID_CODE_POINT, INVALID_CODE_POINT, error);
        }
    }
}

- (BOOL)hasCanonicalGlyphNames {
    return FT_HAS_GLYPH_NAMES(face);
}

- (NSString*)canonicalNameOfGlyph:(NSUInteger)gid {
    if (!FT_HAS_GLYPH_NAMES(face))
        return nil;
    char glyphName[256] = {0};
    if (!FT_Get_Glyph_Name(face, gid, glyphName, 256))
        return [NSString stringWithUTF8String:glyphName];
    return nil;
}

- (NSString*)composedNameOfGlyph:(NSUInteger)gid {
    TypefaceGlyphName * name = [glyphNameCache lookupByGID:gid];
    if (name)
        return [NSString stringWithUTF8String:name->name.c_str()];
    return nil;
}


- (CGFloat)fontUnitToPixelWithDefaultFontSize:(NSInteger)u {
    return [self fontUnitToPixel:u];
}

- (CGFloat)fontUnitToPixel:(NSInteger)u withFontSize:(CGFloat)fontSize {
    return [self ptToPixel:u/(CGFloat)(face->units_per_EM) * fontSize];
}

- (CGFloat)fontUnitToPixel:(NSInteger)u {
    return [self fontUnitToPixel:u withFontSize:_fontSize];
}

- (CGFloat)ptToPixel:(CGFloat)pt {
    return pt * self.dpi / 72.0;
}


#pragma mark *** Names ***

- (NSString*)composeNameForGlyph:(NSUInteger)gid code:(NSUInteger)code isUnicode:(BOOL)isUnicode{
    char glyphName[256] = {0};
    if (gid && FT_HAS_GLYPH_NAMES(face)) {
        FT_Get_Glyph_Name(face, gid, glyphName, 256);
    }
    if (glyphName[0]) {
        return [NSString stringWithUTF8String:glyphName];
    }
    else {
        NSString * hex = [CharEncoding hexForCharcode:code unicodeFlavor:isUnicode];
        return hex? hex: UNDEFINED_UNICODE_CODEPOINT;
    }
}

- (void)dealloc {
    FT_Done_Face(face);
}


@end



#pragma mark  ###### TypefaceCMap ######

@interface TypefaceCMapPlatform : NSObject {
    NSMutableArray<TypefaceGlyphBlock*> * _unicodeBlocks;
    NSMutableDictionary<NSNumber*, NSArray<TypefaceGlyphBlock*>* > *_encodingBlocksCache;
}
@property (readonly) NSUInteger platformId;
@property (readonly, strong) NSString * platformName;

- (id) initWithPlatformId:(NSUInteger)platformId;
- (NSString*)cmapNameOfEncoding:(NSUInteger)encoding;
- (NSArray<TypefaceGlyphBlock*>*) glyphBlocksOfEncoding:(NSUInteger)encoding;

+ (TypefaceCMapPlatform*)platformById:(NSUInteger)platformId;
+ (NSString*)cmapNameOfPlatform:(NSUInteger)platformId encodong:(NSUInteger)encodingId;

@end

@interface TypefaceCMap () {
    NSMutableArray<TypefaceGlyphBlock*> * _blocks;
}
@end

static NSMutableArray<TypefaceCMapPlatform*> * _allCMapPlatforms;
@implementation TypefaceCMapPlatform
- (id)initWithPlatformId:(NSUInteger)platformId {
    if (self = [super init]) {
        _encodingBlocksCache = [[NSMutableDictionary<NSNumber*, NSArray<TypefaceGlyphBlock*>* > alloc] init];
        _platformId = platformId;
    }
    return self;
}

- (NSString*)cmapNameOfEncoding:(NSUInteger)encoding {
    return FTGetPlatformEncodingName(self.platformId, encoding);
}

#pragma mark **** GlyphBlock ****
- (NSArray<TypefaceGlyphBlock*>*)glyphBlocksOfEncoding:(NSUInteger)encoding {
    NSArray<TypefaceGlyphBlock*>* blocks = [_encodingBlocksCache objectForKey:[NSNumber numberWithUnsignedInteger:encoding]];
    if (blocks)
        return blocks;
    
    switch(_platformId) {
        case TT_PLATFORM_APPLE_UNICODE: blocks = [self loadUnicodeGlyphBlocksOfEncoding:encoding]; break;
        case TT_PLATFORM_MACINTOSH: blocks = [self loadMacintoshGlyphBlocksOfEncoding:encoding]; break;
        case TT_PLATFORM_ISO: blocks =  [self loadISOGlyphBlocksOfEncoding:encoding]; break;
        case TT_PLATFORM_MICROSOFT: blocks =  [self loadMicrosoftGlyphBlocksOfEncoding:encoding]; break;
        case TT_PLATFORM_ADOBE: blocks =  [self loadAdobeGlyphBlocksOfEncoding:encoding]; break;
        default:
            blocks = nil;
    }
    if (!blocks) {
        NSLog(@"Encoding blocks for cmap %@ not found!", [self cmapNameOfEncoding:encoding]);
        blocks = [[NSArray<TypefaceGlyphBlock*> alloc] init];
    }
    [_encodingBlocksCache setObject:blocks forKey:[NSNumber numberWithUnsignedInteger:encoding]];
    return blocks;
}
- (NSArray<TypefaceGlyphBlock*>*) loadUnicodeGlyphBlocksOfEncoding:(NSUInteger)encoding {
    return [self loadUnicodeBlocksOfVersion:nil];
}

- (NSArray<TypefaceGlyphBlock*>*) loadMacintoshGlyphBlocksOfEncoding:(NSUInteger)encoding {
    switch(encoding) {
        case TT_MAC_ID_ROMAN:
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0 to:255 isGID:NO name:@"Mac Roman"] ];
        default: return nil;
    }
}

- (NSArray<TypefaceGlyphBlock*>*) loadMicrosoftGlyphBlocksOfEncoding:(NSUInteger)encoding {
    switch(encoding) {
        case TT_MS_ID_UNICODE_CS:
        case TT_MS_ID_UCS_4:
            return [self loadUnicodeGlyphBlocksOfEncoding:encoding];
        case TT_MS_ID_SYMBOL_CS:
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0xF020 to:0xF0FF isGID:NO name:@"Windows Symbol"] ];
        default:
            return nil;
    }
    
    return nil;
}

- (NSArray<TypefaceGlyphBlock*>*) loadISOGlyphBlocksOfEncoding:(NSUInteger)encoding {
    return nil;
}

- (NSArray<TypefaceGlyphBlock*>*) loadAdobeGlyphBlocksOfEncoding:(NSUInteger)encoding {
    switch(encoding) {
        case TT_ADOBE_ID_STANDARD:
            // https://www.compart.com/en/unicode/charsets/Adobe-Standard-Encoding
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0 to:255 isGID:NO name:@"Standard"] ];
        case TT_ADOBE_ID_EXPERT:
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0 to:255 isGID:NO name:@"Expert"] ];
        case TT_ADOBE_ID_CUSTOM:
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0 to:255 isGID:NO name:@"Custom"] ];
        case TT_ADOBE_ID_LATIN_1:
            return @[ [[TypefaceGlyphRangeBlock alloc] initWithFrom:0 to:255 isGID:NO name:@"Latin 1"] ];
        default:
            return nil;
    }
    return nil;
}


- (BOOL) isUnicodeEncoding:(NSUInteger)encoding {
    if (_platformId == TT_PLATFORM_APPLE_UNICODE)
        return YES;
    
    if (_platformId == TT_PLATFORM_MICROSOFT)
        return encoding == TT_MS_ID_UNICODE_CS || encoding == TT_MS_ID_UCS_4;
    
    return NO;
        
};

- (NSArray<TypefaceGlyphBlock*>*)loadUnicodeBlocksOfVersion:(NSString*)version {
    if (_unicodeBlocks)
        return _unicodeBlocks;
    
    _unicodeBlocks= [[NSMutableArray<TypefaceGlyphBlock*> alloc] init];
    
    NSArray<UnicodeBlock*> * uniBlocks = [UnicodeDatabase standardDatabase].unicodeBlocks;
    for (UnicodeBlock * block in uniBlocks) {
        TypefaceGlyphRangeBlock * b = [[TypefaceGlyphRangeBlock alloc] initWithFrom:block.from
                                                                                 to:block.to
                                                                              isGID:NO
                                                                               name:block.name];
        [_unicodeBlocks addObject:b];
    }
    
    return _unicodeBlocks;
}

+ (TypefaceCMapPlatform*)platformById:(NSUInteger)platformId {
    if (!_allCMapPlatforms) {
        _allCMapPlatforms = [[NSMutableArray<TypefaceCMapPlatform*> alloc] init];
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:-1]]; // invalid platform
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:TT_PLATFORM_APPLE_UNICODE]];
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:TT_PLATFORM_MACINTOSH]];
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:TT_PLATFORM_ISO]];
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:TT_PLATFORM_MICROSOFT]];
        [_allCMapPlatforms addObject:[[TypefaceCMapPlatform alloc] initWithPlatformId:TT_PLATFORM_ADOBE]];
    }
    for (TypefaceCMapPlatform * p in _allCMapPlatforms) {
        if (p.platformId == platformId)
            return p;
    }
    return [TypefaceCMapPlatform platformById: -1];
}

+ (NSString*)cmapNameOfPlatform:(NSUInteger)platformId encodong:(NSUInteger)encodingId {
    return [[TypefaceCMapPlatform platformById:platformId] cmapNameOfEncoding:encodingId];
}

@end


@implementation TypefaceCMap

- (id)initWithPlatformId:(NSUInteger)platform encodingId:(NSUInteger)encoding ofFace:(Typeface*)face{
    if (self = [super init]) {
        _platformId = platform;
        _encodingId = encoding;
        _face = face;
        _name = [TypefaceCMapPlatform cmapNameOfPlatform:_platformId encodong:_encodingId];
        
    }
    return self;
}

- (NSArray<TypefaceGlyphBlock*> *)glyphBlocks {
    if (!_blocks)
        _blocks = [self loadGlyphBlocks];
    return _blocks;
}

- (NSMutableArray<TypefaceGlyphBlock*> *)loadGlyphBlocks {
    
    TypefaceCMapPlatform * cmapPlatform = [TypefaceCMapPlatform platformById:_platformId];
    
    NSMutableArray<TypefaceGlyphBlock*> * blocks = [[NSMutableArray<TypefaceGlyphBlock*> alloc] init];
    [blocks addObject:[self allGlyphsBlock]];
    [blocks addObjectsFromArray:[cmapPlatform glyphBlocksOfEncoding:_encodingId]];
    
    return blocks;
}


- (TypefaceGlyphRangeBlock*) allGlyphsBlock {
    TypefaceGlyphRangeBlock * b = [[TypefaceGlyphRangeBlock alloc] initWithFrom:0
                                                                             to:self.face.numOfGlyphs
                                                                          isGID:YES
                                                                           name:@"All Glyphs"];
    return b;
}

- (BOOL)isUnicode {
    return _platformId == TT_PLATFORM_APPLE_UNICODE
    || (_platformId == TT_PLATFORM_MICROSOFT && ( _encodingId == TT_MS_ID_UNICODE_CS || _encodingId == TT_MS_ID_UCS_4))
    ;
}
@end


