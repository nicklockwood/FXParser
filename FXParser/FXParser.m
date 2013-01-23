//
//  FXParser.m
//
//  Version 1.0
//
//  Created by Nick Lockwood on 15/01/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXParser
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "FXParser.h"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


NSString *const FXParserException = @"FXParserException";


@interface FXParserResult ()

@property (nonatomic) BOOL success;
@property (nonatomic) id value;
@property (nonatomic) NSRange remaining;
@property (nonatomic) NSArray *children;
@property (nonatomic) NSString *expected;

@end


@implementation FXParserResult

+ (instancetype)successWithValue:(id)value remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.success = YES;
    result.value = value;
    result.remaining = remaining;
    return result;
}

+ (instancetype)successWithChildren:(NSArray *)children remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.success = YES;
    result.children = children;
    result.remaining = remaining;
    return result;
}

+ (instancetype)failureWithChildren:(NSArray *)children expected:(NSString *)expected remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.children = children;
    result.expected = expected;
    result.remaining = remaining;
    return result;
}

- (id)value
{
    if (!_value && _children)
    {
        NSMutableArray *values = [NSMutableArray array];
        for (FXParserResult *result in _children)
        {
            if (result.value) [values addObject:result.value];
        }
        _value = ([values count] > 1)? values: [values lastObject];
    }
    return _value;
}

- (NSString *)description
{
    if (_success)
    {
        return [NSString stringWithFormat:@"success; %i characters remaining; value: %@",
                (int)_remaining.length, self.value];
    }
    else
    {
        return [NSString stringWithFormat:@"failed; expected: %@; %i characters remaining; value: %@",
                _expected, (int)_remaining.length, self.value];
    }
}

@end


@interface FXParser ()

@property (nonatomic, copy) FXParserBlock block;
@property (nonatomic, copy) NSString *description;

@end


@implementation FXParser

+ (instancetype)parserWithBlock:(FXParserBlock)block description:(NSString *)description
{
    FXParser *parser = [[[self class] alloc] init];
    parser.block = block;
    parser.description = description;
    return parser;
}

+ (instancetype)stringMatchingPredicate:(FXParserStringPredicate)predicate description:(NSString *)description
{
    return [self parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        NSRange result = predicate(input, range);
        if (result.location == range.location)
        {
            return [FXParserResult successWithValue:[input substringWithRange:result] remaining:NSMakeRange(range.location + result.length, range.length - result.length)];
        }
        return [FXParserResult failureWithChildren:nil expected:description remaining:range];
        
    } description:description];
}

+ (instancetype)regexp:(NSString *)pattern
{
    return [self stringMatchingPredicate:^NSRange(NSString *input, NSRange range) {
        
        return [input rangeOfString:pattern options:NSRegularExpressionSearch|NSAnchoredSearch range:range];
        
    } description:[NSString stringWithFormat:@"a string matching the pattern %@", pattern]];
}

+ (instancetype)regexp:(NSString *)pattern replacement:(NSString *)replacement
{
    return [[self regexp:pattern] withTransform:^id(id value) {
        
        NSRegularExpression *expression = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:NULL];
        return [expression stringByReplacingMatchesInString:[value description]
                                                    options:NSMatchingAnchored
                                                      range:NSMakeRange(0, [value length])
                                               withTemplate:replacement];
    }];
}

+ (instancetype)string:(NSString *)string
{
    return [self stringMatchingPredicate:^NSRange(NSString *input, NSRange range) {
        
        return [input rangeOfString:string options:NSAnchoredSearch range:range];
        
    } description:string];
}

- (instancetype)parserWithDescription:(NSString *)description
{
    return [[self class] parserWithBlock:_block description:description];
}

+ (instancetype)forwardDeclaration
{
    return [[[self class] alloc] init];
}

- (void)setImplementation:(FXParser *)implementation
{
    if (_block)
    {
        [NSException raise:@"Implementation has already been set" format:nil];
    }
    _block = implementation.block;
    _description = implementation.description;
}

- (FXParserResult *)parse:(NSString *)input range:(NSRange)range
{
    return _block(input, range);
}

- (FXParserResult *)parse:(NSString *)input
{
    if (!_block)
    {
        [NSException raise:@"No implementation has been set" format:nil];
    }
    return [self parse:input range:NSMakeRange(0, [input length])];
}

@end


@implementation FXParser (Combinators)

+ (instancetype)sequence:(NSArray *)parsers
{
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        NSMutableArray *children = [NSMutableArray array];
        NSRange _range = range;
        for (FXParser *parser in parsers)
        {
            FXParserResult *result = [parser parse:input range:_range];
            if (!result.success)
            {
                return [FXParserResult failureWithChildren:children expected:[parser description] remaining:_range];
            }
            if (result.children)
            {
                [children addObjectsFromArray:result.children];
            }
            else
            {
                [children addObject:result];
            }
            _range = result.remaining;
        }
        return [FXParserResult successWithChildren:children remaining:_range];
        
    } description:[parsers count]? [parsers[0] description]: @""];
}

+ (instancetype)oneOf:(NSArray *)parsers
{
    NSArray *descriptions = [parsers valueForKeyPath:@"@distinctUnionOfObjects.description"];
    NSString *description = ([descriptions count] > 1)? [NSString stringWithFormat:@"either %@", [descriptions componentsJoinedByString:@" or "]]: [descriptions lastObject];
    
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *bestUnsuccessful = nil;
        FXParserResult *bestSuccessful = nil;
        
        //TODO: proper precedence system
        for (FXParser *parser in parsers)
        {
            FXParserResult *result = [parser parse:input range:range];
            if (result.success)
            {
                if (!bestSuccessful || result.remaining.length < bestSuccessful.remaining.length)
                {
                    bestSuccessful = result;
                }
            }
            else if (result.remaining.length < range.length &&
                     (!bestUnsuccessful || result.remaining.length < bestUnsuccessful.remaining.length))
            {
                bestUnsuccessful = result;
            }
        }
        if (bestSuccessful)
        {
            return bestSuccessful;
        }
        else if (bestUnsuccessful)
        {
            return bestUnsuccessful;
        }
        else
        {
            return [FXParserResult failureWithChildren:nil expected:description remaining:range];
        }
    
    } description:description];
}

- (instancetype)optional
{
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = [self parse:input range:range];
        if (result.success)
        {
            return result;
        }
        return [FXParserResult successWithValue:nil remaining:range];
    
    } description:[NSString stringWithFormat:@"an optional %@", self]];
}

- (instancetype)oneOrMore
{
    NSString *description = [NSString stringWithFormat:@"one or more instances of %@", self];
    
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = nil;
        NSMutableArray *children = [NSMutableArray array];
        NSRange _range = range;
        while (_range.length && (result = [self parse:input range:_range]).success)
        {
            if (result.children)
            {
                [children addObjectsFromArray:result.children];
            }
            else
            {
                [children addObject:result];
            }
            _range = result.remaining;
        }
        if ([children count])
        {
            return [FXParserResult successWithChildren:children remaining:_range];
        }
        else
        {
            return [FXParserResult failureWithChildren:nil expected:description remaining:_range];
        }
    
    } description:description];
}

- (instancetype)separatedBy:(FXParser *)parser
{
    return [self then:[[[parser then:self] oneOrMore] optional]];
}

- (instancetype)surroundedBy:(FXParser *)parser
{
    return [FXParser sequence:@[parser, self, parser]];
}

- (instancetype)or:(FXParser *)parser
{
    return [[self class] oneOf:@[self, parser]];
}

- (instancetype)then:(FXParser *)parser
{
    return [[self class] sequence:@[self, parser]];
}

@end


@implementation FXParser (ValueTransforms)

- (instancetype)withTransform:(FXParserValueTransform)transform
{
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = [self parse:input range:range];
        if (result.success)
        {
            return [FXParserResult successWithValue:transform(result.value) remaining:result.remaining];
        }
        return result;
        
    } description:[self description]];
}

- (instancetype)withValueForKeyPath:(NSString *)keyPath
{
    return [self withTransform:^id(id value) {
        
        return [value valueForKeyPath:keyPath];
    }];
}

- (instancetype)withValue:(id)_value
{
    return [self withTransform:^id(id value) {
        
        return _value;
    }];
}

- (instancetype)discard
{
    return [self withTransform:^id(id value) {
        
        return nil;
    }];
}

- (instancetype)array
{
    return [self withTransform:^id(id value) {
        
        if (!value)
        {
            return @[];
        }
        else if (![value isKindOfClass:[NSArray class]])
        {
            return @[value];
        }
        return value;
    }];
}

- (instancetype)dictionary
{
    return [self withTransform:^id(id value) {
        
        if (value && ![value isKindOfClass:[NSArray class]])
        {
            [NSException raise:FXParserException format:@"attempted to convert %@ to a dictionary", [value class]];
        }
        if ([value count] % 2 != 0)
        {
            [NSException raise:FXParserException format:@"array has odd number of elements"];
        }
        
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        for (int i = 0; i < [value count]; i += 2)
        {
            results[value[i]] = value[i + 1];
        }
        return results;
    }];
}

- (instancetype)join:(NSString *)glue
{
    return [self withTransform:^id(id value) {
        
        if (value && ![value isKindOfClass:[NSArray class]])
        {
            [NSException raise:FXParserException format:@"attempted to perform join on a %@", [value class]];
        }
        return [value componentsJoinedByString:glue];
    }];
}

@end