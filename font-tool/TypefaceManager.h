//
//  TypefaceManager.h
//  tx-research
//
//  Created by Yuqing Jiang on 6/15/17.
//
//
#import <Foundation/Foundation.h>
#import <AvailabilityMacros.h>

#import "Typeface.h"

extern NSString * TMProgressNotification;

extern NSString * TMProgressNotificationFileKey;
extern NSString * TMProgressNotificationTotalKey;
extern NSString * TMProgressNotificationCurrentKey;

@interface TypefaceAttributesCache : NSObject

- (TypefaceAttributes*)attributesOfTypefaceDescriptor:(TypefaceDescriptor*)descriptor;
- (void)setAttributes:(TypefaceAttributes*)attributes ofTypeface:(TypefaceDescriptor*)descriptor;

+ (TypefaceAttributesCache *)standardCache;
@end

@interface TMTypeface : NSObject
@property NSString           * familyName;
@property NSString           * styleName;
@property NSString           * localizedFamilyName;
@property NSString           * localizedStyleName;
@property TypefaceAttributes * attributes;

- (NSComparisonResult)compare:(TMTypeface*)other;
- (Typeface*)createTypeface;
- (TypefaceDescriptor*)createTypefaceDescriptor;
@end

@interface TMTypeface (NSFont)
- (NSFont*)createFontWithSize:(CGFloat)size;
@end

@interface TMTypefaceFamily : NSObject
@property NSString         * familyName;
@property NSString         * localizedFamilyName;
@property NSArray<TMTypeface*> * faces;

- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToFamily:(TMTypefaceFamily*)other;
- (BOOL)hash;
- (NSComparisonResult)compare:(TMTypefaceFamily*)other;
@end

@interface TypefaceManager : NSObject

-(void)initFTLib;
-(void)doneFTLib;
-(OpaqueFTLibrary)ftLib;

-(NSArray<TMTypefaceFamily*>*)availableTypefaceFamilies;


-(NSArray<NSString*> *)listFacesOfURL:(NSURL*)url;
-(NSString*)faceNameAtIndex:(NSUInteger)index ofURL:(NSURL*)url;
-(NSString*)familyNameAtIndex:(NSUInteger)index ofURL:(NSURL*)url;
-(NSString*)styleNameAtIndex:(NSUInteger)index ofURL:(NSURL*)url;

- (TypefaceDescriptor*)fileDescriptorFromNameDescriptor:(TypefaceDescriptor*)nameDescriptor;

- (void)enumurateFacesOfURL:(NSURL*)url handler:(BOOL (^)(OpaqueFTFace opaqueFace, NSUInteger index))hander;

// return INVALID_FACE_INDEX if not found
- (NSInteger)indexOfFamily:(NSString*)family style:(NSString*)style ofURL:(NSURL*)url DEPRECATED_ATTRIBUTE;

+ (instancetype) defaultManager;
@end