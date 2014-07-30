//
//  FXParser.m
//
//  Version 1.2.1
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
#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"
#pragma GCC diagnostic ignored "-Wgnu"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


NSString *const FXParserException = @"FXParserException";


@interface FXParserResult ()

@property (nonatomic) BOOL success;
@property (nonatomic, strong) id value;
@property (nonatomic, copy) id (^valueBlock)(void);
@property (nonatomic) NSRange matched;
@property (nonatomic) NSRange remaining;
@property (nonatomic) NSArray *children;
@property (nonatomic) NSString *expected;

@end


@implementation FXParserResult

+ (instancetype)successWithValue:(id)value matched:(NSRange)matched remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.success = YES;
    result.value = value;
    result.matched = matched;
    result.remaining = remaining;
    return result;
}

+ (instancetype)successWithValueBlock:(id (^)(void))valueBlock matched:(NSRange)matched remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.success = YES;
    result.valueBlock = valueBlock;
    result.matched = matched;
    result.remaining = remaining;
    return result;
}

+ (instancetype)successWithChildren:(NSArray *)children matched:(NSRange)matched remaining:(NSRange)remaining
{
    FXParserResult *result = [[self alloc] init];
    result.success = YES;
    result.children = children;
    result.matched = matched;
    result.remaining = remaining;
    return result;
}

+ (instancetype)failureWithChildren:(NSArray *)children matched:(NSRange)matched remaining:(NSRange)remaining expected:(NSString *)expected
{
    FXParserResult *result = [[self alloc] init];
    result.children = children;
    result.expected = expected;
    result.matched = matched;
    result.remaining = remaining;
    return result;
}

- (id)value
{
    if (_valueBlock)
    {
        _value = _valueBlock();
        _valueBlock = NULL;
    }
    if (!_value && self.children)
    {
        NSMutableArray *values = [NSMutableArray array];
        for (FXParserResult *result in self.children)
        {
            if (result.value) [values addObject:result.value];
        }
        _value = ([values count] > 1)? values: [values lastObject];
    }
    return _value;
}

- (NSString *)description
{
    if (self.success)
    {
        return [NSString stringWithFormat:@"success; %i characters remaining; value: %@",
                (int)self.remaining.length, self.value];
    }
    else
    {
        return [NSString stringWithFormat:@"failed; expected: %@; %i characters remaining; value: %@",
                self.expected, (int)self.remaining.length, self.value];
    }
}

@end


@interface FXParser () <NSCopying>

@property (nonatomic, copy) FXParserBlock block;
@property (nonatomic, copy) NSString *description;
@property (nonatomic, readwrite) NSString *name;

@end


@implementation FXParser

@synthesize description = _description;

+ (instancetype)parserWithBlock:(FXParserBlock)block description:(NSString *)description
{
    FXParser *parser = [[self alloc] init];
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
            return [FXParserResult successWithValueBlock:^{
                
                return [input substringWithRange:result];
                
            } matched:result remaining:NSMakeRange(range.location + result.length, range.length - result.length)];
        }
        return [FXParserResult failureWithChildren:nil matched:NSMakeRange(range.location, 0) remaining:range expected:description];
        
    } description:description];
}

+ (instancetype)regexp:(NSString *)pattern replacement:(NSString *)replacement
{
    NSString *description = [NSString stringWithFormat:@"string matching the pattern \"%@\"", pattern];
    if (replacement)
    {
        description = [description stringByAppendingFormat:@" with replacement \"%@\"", replacement];
    }
    
    NSError *error = nil;
    NSRegularExpression *exp = [[NSRegularExpression alloc] initWithPattern:pattern options:(NSRegularExpressionOptions)0 error:&error];
    if (!exp)
    {
        [NSException raise:FXParserException format:@"Error parsing regular expression: %@", [error localizedDescription]];
    }

    if (!replacement)
    {
        return [self stringMatchingPredicate:^NSRange(NSString *input, NSRange range) {
            
            return [exp firstMatchInString:input options:NSMatchingAnchored range:range].range;
            
        } description:description];
    }
    else
    {
        return [self parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
            
            NSTextCheckingResult *result = [exp firstMatchInString:input options:NSMatchingAnchored range:range];
            if (result && result.range.location == range.location)
            {
                return [FXParserResult successWithValueBlock:^{
                    
                    return [exp replacementStringForResult:result inString:input offset:0 template:replacement];
                    
                } matched:result.range remaining:NSMakeRange(range.location + result.range.length, range.length - result.range.length)];
            }
            return [FXParserResult failureWithChildren:nil matched:NSMakeRange(range.location, 0) remaining:range expected:description];
            
        } description:description];
    }
}

+ (instancetype)regexp:(NSString *)pattern
{
    return [self stringMatchingPredicate:^NSRange(NSString *input, NSRange range) {
        
        return [input rangeOfString:pattern options:(NSStringCompareOptions)(NSRegularExpressionSearch|NSAnchoredSearch) range:range];
        
    } description:[NSString stringWithFormat:@"string matching the pattern \"%@\"", pattern]];
}

+ (instancetype)string:(NSString *)string
{
    return [self stringMatchingPredicate:^NSRange(NSString *input, NSRange range) {
        
        return [input rangeOfString:string options:NSAnchoredSearch range:range];
        
    } description:[NSString stringWithFormat:@"\"%@\"", string]];
}

- (id)copyWithZone:(NSZone *)zone
{
    FXParser *parser = [[[self class] allocWithZone:zone] init];
    parser.block = self.block;
    parser.description = self.description;
    parser.name = self.name;
    return parser;
}

- (instancetype)withDescription:(NSString *)description
{
    FXParser *parser = [self copy];
    parser.description = description;
    return parser;
}

- (instancetype)withName:(NSString *)name
{
    FXParser *parser = [self copy];
    parser.name = name;
    return parser;
}

+ (instancetype)forwardDeclarationWithName:(NSString *)name
{
    FXParser *parser = [[self alloc] init];
    parser.description = @"<forward declaration>";
    parser.name = name;
    return parser;
}

- (void)setImplementation:(FXParser *)implementation
{
    if (self.block)
    {
        [NSException raise:@"Implementation has already been set" format:nil];
    }
    self.block = implementation.block;
    self.description = implementation->_description;
    self.name = implementation.name ?: self.name;
}

- (FXParserResult *)parse:(NSString *)input range:(NSRange)range
{
    if (!self.block)
    {
        [NSException raise:@"No implementation has been set" format:nil];
    }
    return self.block(input, range);
}

- (FXParserResult *)parse:(NSString *)input
{
    return [self parse:input range:NSMakeRange(0, [input length])];
}

- (NSString *)shortDescription
{
    return self.name? [NSString stringWithFormat:@"%@(%p)", self.name, self]: _description;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@:%p name = \"%@\"; description = \"%@\"; >", [self class], self, self.name, _description];
}

- (NSString *)description
{
    NSString *description = _description ?: self.name;
    return [description stringByReplacingOccurrencesOfString:@"\\(0x[0-9a-f]+\\)" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [description length])];
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
                return [FXParserResult failureWithChildren:children
                                                   matched:NSMakeRange(range.location, _range.location - range.location)
                                                 remaining:_range expected:[parser description]];
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
        return [FXParserResult successWithChildren:children matched:NSMakeRange(range.location, _range.location - range.location) remaining:_range];
        
    } description:[[parsers valueForKey:@"shortDescription"] componentsJoinedByString:@" then "] ?: @""];
}

+ (instancetype)oneOf:(NSArray *)parsers
{
    NSArray *descriptions = [parsers valueForKeyPath:@"@distinctUnionOfObjects.shortDescription"];
    NSString *description = ([descriptions count] > 1)? [NSString stringWithFormat:@"either %@", [descriptions componentsJoinedByString:@" or "]]: [descriptions lastObject];
    
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *bestUnsuccessful = nil;
        FXParserResult *bestSuccessful = nil;
        
        //if there are multiple matches, take the longest
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
            return [FXParserResult failureWithChildren:nil matched:NSMakeRange(range.location, 0) remaining:range expected:description];
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
        return [FXParserResult successWithValue:nil matched:NSMakeRange(range.location, 0) remaining:range];
    
    } description:[NSString stringWithFormat:@"optional %@", [self shortDescription]]];
}

- (instancetype)zeroOrMoreTimes
{
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
        return [FXParserResult successWithChildren:children matched:NSMakeRange(range.location, _range.location - range.location) remaining:_range];
        
    } description:[NSString stringWithFormat:@"zero or more instances of %@", [self shortDescription]]];
}

- (instancetype)oneOrMoreTimes
{
    NSString *description = [NSString stringWithFormat:@"one or more instances of %@", [self shortDescription]];
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = [[self zeroOrMoreTimes] parse:input range:range];
        if (result.success)
        {
            if ([result.children count])
            {
                return result;
            }
            else
            {
                return [FXParserResult failureWithChildren:nil matched:result.matched remaining:result.remaining expected:[self description]];
            }
        }
        return result;
        
    } description:description];
}

- (instancetype)twoOrMoreTimes
{
    NSString *description = [NSString stringWithFormat:@"two or more instances of %@", [self shortDescription]];
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = [[self zeroOrMoreTimes] parse:input range:range];
        if (result.success)
        {
            if ([result.children count] >= 2)
            {
                return result;
            }
            else
            {
                return [FXParserResult failureWithChildren:nil matched:result.matched remaining:result.remaining expected:[self description]];
            }
        }
        return result;
        
    } description:description];
}

- (instancetype)separatedBy:(FXParser *)parser
{
    return [self then:[[[parser then:self] oneOrMoreTimes] optional]];
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


@implementation FXParser (ValueTransformers)

- (instancetype)withTransformer:(FXParserValueTransformer)transformer
{
    return [FXParser parserWithBlock:^FXParserResult *(NSString *input, NSRange range) {
        
        FXParserResult *result = [self parse:input range:range];
        if (result.success)
        {
            return [FXParserResult successWithValueBlock:^{ return transformer(result.value); } matched:result.matched remaining:result.remaining];
        }
        return result;
        
    } description:[[self shortDescription] stringByAppendingString:@" with custom transform"]];
}

- (instancetype)withValueForKeyPath:(NSString *)keyPath
{
    return [[self withTransformer:^id(id value) {
        
        return [value valueForKeyPath:keyPath];
        
    }] withDescription:[[self shortDescription] stringByAppendingFormat:@" with value for keyPath %@", keyPath]];
}

- (instancetype)withValue:(id)value
{
    return [[self withTransformer:^id(__unused id discardedValue) {
        
        return value;
        
    }] withDescription:[[self shortDescription] stringByAppendingFormat:@" with value %@", value]];
}

- (instancetype)discard
{
    return [[self withTransformer:^id(__unused id discardedValue) {
        
        return nil;
        
    }] withDescription:[[self shortDescription] stringByAppendingString:@" with discarded value"]];
}

- (instancetype)asArray
{
    return [[self withTransformer:^id(id value) {
        
        if (!value)
        {
            return @[];
        }
        else if (![value isKindOfClass:[NSArray class]])
        {
            return @[value];
        }
        return value;
        
    }] withDescription:[[self shortDescription] stringByAppendingString:@" as array"]];
}

- (instancetype)asDictionary
{
    return [[self withTransformer:^id(NSArray *value) {
        
        if (value && ![value isKindOfClass:[NSArray class]])
        {
            [NSException raise:FXParserException format:@"Attempted to convert %@ to a dictionary", [value class]];
        }
        
        if ([value count] % 2 != 0)
        {
            [NSException raise:FXParserException format:@"Array has odd number of elements"];
        }
        
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < [value count]; i += 2)
        {
            results[value[i]] = value[i + 1];
        }
        return results;
        
    }] withDescription:[[self shortDescription] stringByAppendingString:@" as dictionary"]];
}

- (instancetype)asString
{
    return [[self withTransformer:^id(id value) {
        
        if ([value isKindOfClass:[NSArray class]])
        {
            return [value componentsJoinedByString:@""];
        }
        return [value description] ?: @"";
        
    }]  withDescription:[[self shortDescription] stringByAppendingString:@" as string"]];
}

- (instancetype)withComponentsJoinedByString:(NSString *)glue
{
    return [[self withTransformer:^id(id value) {
        
        if ([value isKindOfClass:[NSArray class]])
        {
            return [value componentsJoinedByString:glue];
        }
        return [value description];
        
    }] withDescription:[[self shortDescription] stringByAppendingFormat:@" joined by string \"%@\"", glue]];
}

@end


@implementation FXParser (Grammar)

+ (instancetype)grammarParserWithTransformer:(FXParser *(^)(NSString *name, FXParser *parser))transformer
{
    //create dictionaries for identifiers and grammar
    NSMutableDictionary *identifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *parsers = [NSMutableDictionary dictionary];
    
    //spacing
    FXParser *whitespace = [[FXParser regexp:@"\\s*"] discard];
    FXParser *linebreak = [[FXParser regexp:@"(\\s*\n)+"] discard];
    
    //comment
    FXParser *comment = [[FXParser regexp:@"\\s*#.*"] discard];
    
    //identifiers
    FXParser *identifier = [[FXParser regexp:@"[a-zA-Z][a-zA-Z0-9_-]*"] withTransformer:^id(NSString *name) {
        
        FXParser *parser = identifiers[name];
        if (!parser)
        {
            parser = [FXParser forwardDeclarationWithName:name];
            identifiers[name] = parser;
        }
        return parser;
    }];
    
    //string
    FXParser *quote = [[FXParser string:@"\""] discard];
    FXParser *escapedChar = [FXParser regexp:@"\\\\(\")" replacement:@"$1"];
    FXParser *backspace = [FXParser regexp:@"\\\\b" replacement:@"\b"];
    FXParser *formfeed = [FXParser regexp:@"\\\\f" replacement:@"\f"];
    FXParser *linefeed = [FXParser regexp:@"\\\\n" replacement:@"\n"];
    FXParser *carriageReturn = [FXParser regexp:@"\\\\r" replacement:@"\r"];
    FXParser *tab = [FXParser regexp:@"\\\\t" replacement:@"\t"];
    FXParser *stringEscape = [FXParser oneOf:@[escapedChar, backspace, formfeed, linefeed, carriageReturn, tab]];
    FXParser *string = [[FXParser sequence:@[quote, [[[[stringEscape or:[FXParser regexp:@"[^\\\"]"]] oneOrMoreTimes] optional] asString], quote]] withTransformer:^(id value) {
        
        return [FXParser string:value];
    }];
    
    //regex
    FXParser *solidus = [[FXParser string:@"/"] discard];
    FXParser *escapedSolidus = [[FXParser string:@"\\/"] withValue:@"/"];
    FXParser *regexPattern = [[[[escapedSolidus or:[FXParser regexp:@"[^\\/\n]"]] oneOrMoreTimes] optional] asString];
    FXParser *regexReplacement = [[[[stringEscape or:[FXParser regexp:@"[^\\/\n]"]] oneOrMoreTimes] optional] withComponentsJoinedByString:@""]; //join with "" so empty string is discarded
    FXParser *regex = [[FXParser sequence:@[solidus, regexPattern, solidus]] withTransformer:^id(NSString *pattern) {
        
        return [FXParser regexp:pattern];
    }];
    FXParser *regexReplace = [[FXParser sequence:@[[[FXParser string:@"s"] discard], solidus, regexPattern, solidus, regexReplacement, solidus]] withTransformer:^id(id patternAndReplacement) {
        
        if ([patternAndReplacement isKindOfClass:[NSString class]])
        {
            return [[FXParser regexp:patternAndReplacement] discard];
        }
        else
        {
            return [FXParser regexp:patternAndReplacement[0] replacement:patternAndReplacement[1]];
        }
    }];
    
    //rules
    FXParser *primitive = [FXParser oneOf:@[string, regex, regexReplace, identifier]];
    FXParser *subexpression = [FXParser forwardDeclarationWithName:@"subexpression"];
    FXParser *optional = [[[primitive or:subexpression] then:[[FXParser string:@"?"] discard]] withTransformer:^id(FXParser *p) {
        
        return [p optional];
    }];
    FXParser *zeroOrMore = [[[primitive or:subexpression] then:[[FXParser string:@"*"] discard]] withTransformer:^id(FXParser *p) {
        
        return [p zeroOrMoreTimes];
    }];
    FXParser *oneOrMore = [[[primitive or:subexpression] then:[[FXParser string:@"+"] discard]] withTransformer:^id(FXParser *p) {
        
        return [p oneOrMoreTimes];
    }];
    FXParser *repetitions = [FXParser oneOf:@[optional, zeroOrMore, oneOrMore]];
    FXParser *options = [[[FXParser oneOf:@[primitive, subexpression, repetitions]] then:[[[[FXParser regexp:@"\\s*\\|\\s*"] discard] then:[FXParser oneOf:@[primitive, subexpression, repetitions]]] oneOrMoreTimes]] withTransformer:^id(NSArray *list) {
        
        return [FXParser oneOf:list];
    }];
    FXParser *sequence = [[[FXParser oneOf:@[primitive, subexpression, repetitions, options]] then:[[[[FXParser regexp:@" "] discard] then:[FXParser oneOf:@[primitive, subexpression, repetitions, options]]] oneOrMoreTimes]] withTransformer:^id(NSArray *seq) {
        
        return [FXParser sequence:seq];
    }];
    [subexpression setImplementation:[FXParser sequence:@[[[FXParser string:@"("] discard], [FXParser oneOf:@[primitive, repetitions, options, sequence, subexpression]], [[FXParser string:@")"] discard]]]];
    FXParser *rule = [[FXParser sequence:@[identifier, whitespace, [FXParser oneOf:@[primitive, repetitions, options, sequence, subexpression]]]] withTransformer:^id(NSArray *r) {
        
        FXParser *parser = [r firstObject];
        FXParser *implementation = [r lastObject];
        if (transformer)
        {
            implementation = transformer(parser.name, implementation);
        }
        [parser setImplementation:implementation];
        parsers[parser.name] = parser;
        return parser;
    }];
    
    //parse grammar
    FXParser *line = [comment or:[rule then:[comment optional]]];
    return [[[line asArray] separatedBy:linebreak] withValue:parsers];
}

@end
