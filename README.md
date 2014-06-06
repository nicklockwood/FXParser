[![Build Status](https://travis-ci.org/nicklockwood/FXParser.svg)](https://travis-ci.org/nicklockwood/FXParser)


Purpose
--------------

FXParser is a text parsing engine for iOS and Mac OS designed to simplify the consumption of text-based languages and data formats, e.g. JSON.

FXParser is a parser combinator - a type of parser based around composing a complex parser object from many simpler ones. This approach is much simpler than traditional parsers, and avoids the need for a separate lexing/tokenizing stage.

FXParser was heavily influenced by the Parcoa parser (https://github.com/brotchie/Parcoa) which you should also look at if you are interested in parsing engines.

The primary difference between FXParser and Parcoa is that FXParser uses regular expressions to define the individual parser components, rather than working on a character-by-character basis. This greatly reduces the size and complexity of both the FXParser engine itself and also the grammar definitions for individual parsers.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 7.1 / Mac OS 10.9 (Xcode 5.1, Apple LLVM compiler 5.1)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

FXParser requires ARC. If you wish to use FXParser in a non-ARC project, just add the -fobjc-arc compiler flag to the FXParser.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click FXParser.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in FXParser.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including FXParser.m) are checked.


Installation
---------------

To use FXParser, just drag the class files into your project. FXParser can be subclassed, but normally this is not necessary - instead just create instances using the standard constructors to specify your custom rules.


Usage
---------------

To use FXParser, create an FXParser instance that matches a particular set of criteria, then use it to parse a string, like this:

    //create a parser that matches the word 'dog'
    FXParser *dog = [FXParser string:@"dog"];
    
    //create a parser that matches the word 'cat'
    FXParser *cat = [FXParser string:@"cat"];
    
    //create a composite parser that matches either
    FXParser *pet = [dog or:cat];
    
    //parse a string
    FXParserResult *result = [pet parse:@"cow"];
    NSLog(@"%@", result); // will return failure because a cow is not a pet
    
For more examples, have a look at the test app included with the project.
    

Classes
-----------------

FXParser consists of two classes:

1. FXParser - This class represents a parser instance. Using the various constructor methods you can create FXParser instances to match various strings, and combine them to form composite parsers that will match a more complex grammar.
    
2. FXParserResult - This class encapsulates the result of a parsing operation. It will return success or failure, along with the parsed result and any relevant metadata.


FXParser
-------------

FXParser's methods break down into three types, which have been split into separate Categories to make things clearer:

1. Core functionality - this includes all the standard parser constructors and methods for parsing strings.
    
2. Combinators - these are methods for combining parsers to make more complex rules.
    
3. Value transformers - these methods are used to process the results returned by the parser so you can create output in a specific format.


Core functionality
--------------------

These are the basic functions used to create and apply a parser.

    + (instancetype)parserWithBlock:(FXParserBlock)block description:(NSString *)description;
    
This is the designated constructor for FXParser. It creates a parser with a block to specify the criteria that the parser is trying to match, and a description of what the block is trying to match, which is used to generate meaningful errors in the event that parsing fails. The FXParserBlock block has the following signature:

    FXParserResult *(^FXParserBlock)(NSString *input, NSRange range);
    
The parser block takes an input string and a range for it to parse, and returns an FXParserResult object indicating success or failure. Usage of the parserWithBlock: method is quite complex, and normally you would use one of the other, simpler constructor methods to create your parser unless you need very custom behaviour.
    
    + (instancetype)stringMatchingPredicate:(FXParserStringPredicate)predicate description:(NSString *)description;

This method creates a parser that will match the specified FXParserStringPredicate block. Note that an FXParserStringPredicate is not the same thing as an NSPredicate, although it follows the same principle. The FXParserStringPredicate block has the following signature:
    
    NSRange (^FXParserStringPredicate)(NSString *input, NSRange range);
    
The predicate block takes an input string and a range for it to parse, and returns an NSRange object that is used to indicate both success/failure and the amount of text consumed. Use of NSRange as the return value may seem cumbersome, but it's quite easy to use with the built-in NSString matching functions. For a successful match, the range.location should always match up with the range supplied to the predicate. If it does, the match is assumed to be successful even if the length is zero (it is possible to have rules that match zero characters). An unsuccessful match should return a range with a location value of NSNotFound (this is the default behaviour of NSString's rangeOfString: method). Note that it is not acceptable to return a successful match that does not start at the beginning of the specified range - if you wish to ignore leading white space in your predicate matching rules that's fine, but make sure that any ignored white space is still included in the returned range value.

    + (instancetype)string:(NSString *)string;

This method creates a parser that will match the specified string. The string can be a single character or a whole sentence. The parser requires the string to match exactly, including case and white space. If you want to be more flexible, use a regexp matcher instead.

    + (instancetype)regexp:(NSString *)pattern;
    
This method creates a parser that will match the specified regular expression.

    + (instancetype)regexp:(NSString *)pattern replacement:(NSString *)replacement;
    
This method creates a parser that will match the specified regular expression, but can replace the captured text using a replacement template string, where $0-n can be used to represent the captured subexpressions from the regexp. (This replacement is technically a type of value transform, but it makes sense to include it in the constructor so you do not have to duplicate the regexp pattern in a separate call).

    - (instancetype)withDescription:(NSString *)description;
    
This method can be used to override the description of an existing parser. So for example, for a parser that matches the regular expression \d you might want to change the description from the default "a string matching the pattern \d" to "a numeric digit". Note that FXParser objects are (mostly) immutable, so rather than modifying the parser, this will create and return a new parser object that matches the behaviour of the original but uses the new description.
    
    - (instancetype)withName:(NSString *)name;

This method can be used to override the name of an existing parser. This lets you provide simple, readable names for your parsers, without having to override the description and lose detail when debugging. You can check a parser's name via the 'name' property.
    
    + (instancetype)forwardDeclarationWithName:(NSString *)name;
    
Sometimes it is necessary to create recursive rules, which can be difficult if you end up needing to refer to a parser before you've defined it. The `forwardDeclaration` constructor creates a "blank" parser that you can use within another parser definition on the understanding that you will supply the implementation using the `setImplementation:` method before you attempt to parse anything. Attempting to parse any text before the implementation has been set will throw an exception. This method also sets the parser name so that it's easier to identify later if something goes wrong and the implementation is never set.
    
    - (void)setImplementation:(FXParser *)implementation;
    
This method is used to set the implementation of a parser that was created using the `forwardDeclaration` constructor. It will copy the logic and description of the supplied parser into the original object. Attempting to set the implementation of a parser that has already been set, or was created using a different constructor, will throw an exception.
        
    - (FXParserResult *)parse:(NSString *)input;
    
This method will attempt to parse the specified string and return an FXParserResult object representing success or failure.
    
    - (FXParserResult *)parse:(NSString *)input range:(NSRange)range;
    
This method works as above, except that you can specify a range within the string that you wish to parse.


Combinators
--------------------

These methods are used to combine or modify existing parsers to produce more complex parsing rules:

    + (instancetype)sequence:(NSArray *)parsers;
    
This method takes an array of parsers and assembles them to form a single  parser. The resultant parser will succeed only if *all* of the supplied parsers match when applied sequentially to the input.
    
    + (instancetype)oneOf:(NSArray *)parsers;
    
This method method takes an array of parsers and assembles them to form a single  parser. The resultant parser will succeed if *any* of supplied parsers match the input. If more than one of the parsers matches, the one yielding the longest successful match will be used.
    
    - (instancetype)optional;
    
This method returns a new parser that will return success regardless of whether the original parser matches or not. This is useful for matching irrelevant content such as optional white space between tokens.
    
    - (instancetype)zeroOrMoreTimes;
    
This method returns a new parser that will match a sequence of zero or more of the original parser's required strings in sequence.
    
    - (instancetype)oneOrMoreTimes;
    
This method returns a new parser that will match a sequence of one or more of the original parser's required strings in sequence.
    
    - (instancetype)twoOrMoreTimes;
    
This method returns a new parser that will match a sequence of two or more of the original parser's required strings in sequence.
    
    - (instancetype)separatedBy:(FXParser *)parser;
    
This method returns a new parser that will match a sequence of one or more instances of the original parser's expected string, separated by the supplied parser's expected string. For example if the original parser matched a number, and the new parser argument matches a comma, the resultant parser would match a comma-delimited list of numbers.
    
    - (instancetype)surroundedBy:(FXParser *)parser;
    
This is a convenience method that returns a new parser that matches the original string preceded and followed by the supplied parser's expected string. This might be used to match a string in quotes for example, or a token surrounded by white space. It is equivalent to `[FXParser sequence:@[parser, self, parser]]`.
    
    - (instancetype)or:(FXParser *)parser;
    
This method returns a new parser that matches either the original parser's expected string or the supplied parser's expected string. It is equivalent to creating a new parser using `[FXParser oneOf:@[self, parser]].
    
    - (instancetype)then:(FXParser *)parser;

This method returns a new parser that matches the original parser's expected string followed by the supplied parser's expected string. It is equivalent to creating a new parser with `[FXParser sequence:@[self, parser]]`.


Value transformers
--------------------

These methods are used to convert the value returned in the FXParserResult object to a new value. This is useful if you want to control the form that your parsed data is converted to. Note that applying a value transform to a parser will discard any children of the original result.

    - (instancetype)withTransformer:(FXParserValueTransformer)transformer;
    
This is the most flexible value transformer function. It takes a block parameter that can be used to apply an arbitrary function to the value. The FXParserValueTransformer block has the following signature:

    id (^FXParserValueTransformer)(id value);
    
The predicate block takes an input value and returns an output value. How you get from one to the other is up to you, and the values can be of any object type.

    - (instancetype)withComponentsJoinedByString:(NSString *)glue;
    
This converts an array value to a string by joining them together with the supplied "glue" string as a separator using NSArray's `componentsJoinedByString:` method. If the value is not an array, the `description` string will be returned. Unlike the `asString` method, if the value is nil it will *not* be promoted to an empty string.
    
    - (instancetype)withValueForKeyPath:(NSString *)keyPath;
    
Sometimes you want actually want a sub-property of a captured value, or the result of calling a method on the object (e.g. [string lowerCaseString]) - you can use the `withValueForKeyPath:` transformer method for that. Specify a keyPath that will be called on the value object and used to return the replacement value. 
    
    - (instancetype)withValue:(id)value;
    
Sometimes you just want to replace the captured value with a specific replacement value. This method returns the specified value instead of the original. 
    
    - (instancetype)discard;
    
Occasionally you will need to match some data that you are not interested in keeping (e.g. white space). Use the `discard` transform to remove it from the results altogether.
    
    - (instancetype)asArray;
    
Sometimes you will need to match zero or more instances of a pattern, but you need the result to always be returned as an array even if it is an array containing only one object (or none). The `asArray` transform will inspect the value and either return it unmodified if it's already an array, wrap it in an array if it's a single object, or create a new empty array if the value is nil.
    
    - (instancetype)asDictionary;
    
The `asDictionary` transform will take an array value and treat it as an interleaved sequence of keys and objects, which are gathered into an NSDictionary and returned. If the original value is nil, an empty dictionary will be returned. If the original value is not an array, or has an odd number of items, this method will throw an exception.

    - (instancetype)asString;
    
The `asString` transform will take an array of value and join them to make a string using NSArray's `componentsJoinedByString:` method. If the value is not an array, the `description` string will be returned. If the value is nil, an empty string will be returned.

Grammar
--------

Instead of constructing a set of parsers in code, you can instead use the following method to generate a collection of parsers from a text file:

    + (FXParserResult *)parseGrammar:(NSString *)grammarString withTransformer:(FXParser *(^)(NSString *name, FXParser *parser))transformer;
    
The grammarString should consist of one or more lines, each of the form:

    name    rule
    
Where "name" is the name of a parser, and "rule" is a description of its behaviour. Each rule can consist of one or more of the following primitive types:

    "string" - an exact string to match
    /pattern/ - a regular expression to match
    s/pattern/replacement/ - a regular expression and replacement value (an empty replacement discards value)
    name - the name of another rule
    
These primitive rules can be combined as follows:

    rule rule - multiple rules can be separated by spaces to indicate a sequence
    rule | rule - multiple rules separated by the | character means either/or
    rule? - a rule followed by a ? is optional
    rule+ - a rule followed by a + is repeated one or more times
    rule* - a rule followed by a * is repeated zero or more times
    
Compound rules can be nested using brackets, as follows:

    rule1 (rule2 | rule3)+ - this would mean "rule1 followed by one or more instances of rule2 or 3"
    
You can also add comments to your grammar file using #:

    #comment on its own line
    rulename    rule    #comment following a rule
    
The "transformer" block can be used to substitute a replacement rule for any rule parsed from the grammar. This is useful for implementing custom valueTransformers, which cannot be specified in the grammar file. For example, this would replace the parser "foo" in the grammar with a copy that formats the parsed value as an array:

    [FXParser parseGrammar:grammarString withTransformer:id^(NSString *name, FXParser *parser) {
        
        if ([name isEqualToString:@"foo"])
        {
            return [parser asArray];
        }
        return parser;
    }];
    
The parseGrammar:withTransformer: method returns an FXParserResult indicating success or failure. If result.success == YES, result.value will be a dictionary containing the FXParser objects created from the grammar file.

See the BASICInterpreter and JSONParser examples for more details.


FXParserResult
------------------

The FXParserResult encapsulates the result of applying a parser to some input. It has the following properties:

    @property (nonatomic, readonly) BOOL success;
    
A boolean indicating whether parsing was successful.
    
    @property (nonatomic, readonly) id value;
    
The value returned after parsing the input. This can be either a single value or an array of results.
    
    @property (nonatomic, readonly) NSRange remaining;
    
The remaining range of the input string that was not consumed by the parsing process. Note that for an FXParser to succeed, it does not necessarily have to have consumed all of the available input. If you wish to treat leftover input as an error, you can either enforce this as a custom rule implemented using a custom FXParserBlock, or just check the result to see if the remaining.length > 0. 
    
    @property (nonatomic, readonly) NSArray *children;
    
This is an array (or tree, since each child may have children of its own) of sub-results created by nested FXParsers within the main parser. If the value that was parsed was composed of smaller tokens or structures, you can retrieve information about them by inspecting this value. For example, you can use the `remaining` values of the children to calculate the positions of the child values within the original string. In the event of an unsuccessful parsing, this value will contain all of the successfully matched sub-results up until the point of failure, which may be useful for error recovery.
    
    @property (nonatomic, readonly) NSString *expected;
    
If parsing was successful, this value will be nil. If parsing fails, this value should contain a human-readable (if somewhat terse) description of the expected input at the point of failure.
    
You can construct an FXParserResult using one of the following methods:

    + (instancetype)successWithValue:(id)value remaining:(NSRange)remaining;
    
This is used to generate an FXParserResult that represents a successful parsing operation. The value is the resultant parsed value, the remaining range is the range of the input string that was not consumed. 
    
    + (instancetype)successWithChildren:(NSArray *)children remaining:(NSRange)remaining;
    
This is used to generate an FXParserResult that represents a successful parsing operation where an array of results has been matched (as opposed to a single value). Whilst you could return this array of results as an array of values using the `successWithValue:remaining:` method, this has two disadvantages:

1. The context of the individual results (e.g. their position within the string) is not preserved.

2. Nested rules will produce nested arrays of values instead of a single concatenated array, which may be harder to work with (note that if you want nested arrays of values in the results, you can use the `asArray` value transform method to redefine an array of results as a single array-type value).
    
    + (instancetype)failureWithChildren:(NSArray *)children expected:(NSString *)description remaining:(NSRange)remaining;
    
This method is used to generate an FXParserResult that represents a failed parsing operation. Any successful sub-parsing results (e.g. if the parser found 4 strings but was expecting 5) should be passed as the children parameter. For results that do not have any children, pass nil. The expected string is a description of the next value that was expected at the point when parsing failed. In most cases this is just the `[parser description]` value, but it might be the description of a child parser in the case of partial success. The remaining value will be the range of the unconsumed part of the string, which should match the input range in most cases if the children value is nil, or should match the last child's `remaining` property if not.


Extending FXParser
------------------

FXParser is designed to provide the commonly needed tools for parsing simple languages and text-based formats, but you may require additional features that don't come out of the box. Here are some examples of how to extend the parser with bespoke functionality:

Q. What's the best way to encapsulate a commonly used parser, such as a regular expression that matches numbers?
    
A. The simplest way is probably to create a category on FXParser that adds a new constructor, e.g:
    
    @interface FXParser (Primitives)
    
    + (instancetype)number;
    
    @end
    
    @implementations FXParser (Primitives)
    
    + (instancetype)number
    {
        return [[self regexp:@"-?[0-9]*\\.?[0-9]+"] withDescription:@"a number"];
    }
    
    @end
    
Q. I need to return additional information in my result, such as the range of the originally matched string, or some additional contextual metadata. How can I add additional data to the FXParserResult?

A. The only real option is to subclass FXParserResult and add a new constructor that takes additional values (or make the setters for your new values public). However, if you are using a custom FXParserResult subclass you won't be able to use any of the built-in FXParser constructors, combinators or value transforms except for the `parserWithBlock:description:` designated constructor, as these will all return standard FXParserResult instances instead of your subclass.

You may be able to subclass FXParser and override all the methods that use FXParserResults to make them return your subclass instead, but this is not a very future-proof solution if additional constructors or combinators are added in future.

A better approach is probably to post-process the FXParserResult returned by your parser. For example, by iterating over a result and all of its children and comparing their `remaining` values to the original input range. Given the range of the original input string it should then be possible to create any additional data about the input that you require. If you have a usage scenario that this doesn't cover, file a feature request on the FXParser github page.

Q. I need to implement an operator precedence system so that I can parse arithmetic logic.

A. The solution here would be to subclass FXParser and add a precedence property and a method to set it. You will also need to override the `oneOf:` constructor and modify its precedence logic - which is currently based on the length of the string consumed - to make use of your new property instead. An official operator precedence system will most likely be added in a future release of FXParser.


Release Notes
---------------

Version 1.2

- Parsers now have an optional "name" property that can be used to refer to them in descriptions
- Much improved description methods provide shorter, more readable parser descriptions for debugging
- The -debugDescription method (used when logging parsers in the console) now includes address info for child parsers, making it easier to dig in for more information
- Fixed bug where grammar would return a stray rule called "s" with no implementation
- Fixed bug where grammar would not correctly match an escaped slash in a regular expression

Version 1.1

- Renamed some methods for clarity and to conform better with Objective-C conventions
- Added new grammar specification syntax and built-in parser (implemented using FXParser)
- Improved description methods to provide more detail about parsers
- Added a very simple BASIC interpreter example

Version 1.0.1

- Now conforms to -Weverything warning level

Version 1.0

- Initial release