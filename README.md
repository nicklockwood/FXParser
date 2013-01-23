Purpose
--------------

FXParser is a very simple text parsing engine for iOS and Mac OS designed to simplify the consumption of simple text-based languages and data formats, e.g. JSON.

FXParser is a parser combinator - a type of parser based around composing a complex parser object from many simpler ones. This approach is much simpler than traditional parsers, and avoids the need for a separate lexing/tokenizing stage.

FXParser was heavily influenced by the Parcoa parser (https://github.com/brotchie/Parcoa) which you should also look at if you are interested in parsing engines.

The primary difference between FXParser and Parcoa is that FXParser uses regular expressions to define the individual parser components, rather than wokring on a character-by-character basis. This greatly reduces the size and complexity of both the FXParser engine itself and also the grammer definitions for individual parsers.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 6.0 / Mac OS 10.8 (Xcode 4.5.2, Apple LLVM compiler 4.1)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

FXParser requires ARC. If you wish to use FXParser in a non-ARC project, just add the -fobjc-arc compiler flag to the FXParser.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click FXParser.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in FXParser.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including FXParser.m) are checked.


Installation
---------------

To use FXParser, just drag the class files into your project. FXParser can be subclassed, but normally this is not neccesary - instead just create instances using the standard constructors to specify your custom rules.


Usage
---------------

To use FXParser, create an FXParser instance that matches a particular set of criteria, then use it to parse a string, like this:

    //create a parser that matches the word 'dog'
    FXParser *dog = [FXParser string:@"dog"];
    
    //create a parser that matches the word 'cat'
    FXParser *cat = [FXParser string:@"cat"];
    
    //create a composite  parser that matches either
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

1. Core functionality - this includes all the standard parser consturctors and methods for parsing strings.
    
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
    
The predicate block takes an input string and a range for it to parse, and returns an NSRange object that is used to indicate both success/failure and the amount of text consumed. Use of NSRange as the retunr value may seem cumbersome, but it's quite easy to use with the built-in NSString matching functions. For a successful match, the range.location should always match up with the range supplied to the predicate. If it does, the match is assumed to be successful even if the length is zero (it is possible to have rules that match zero characters). Note that it is not acceptable to return a match that does not start at the beginning of the specified range - if you wish to ignore leading white space in your predicate matching rules that's fine, but make sure that any ignored white space is still included in the returned range value.

    + (instancetype)string:(NSString *)string;

This method creates a parser that will match the specified string. The string can be a single character or a whole sentence. The parser requires the string to match exactly, including case and white space. If you want to be more flexible, use regexp matcher instead.

    + (instancetype)regexp:(NSString *)pattern;
    
This method creates a parser that will match the specified regular expression.

    + (instancetype)regexp:(NSString *)pattern replacement:(NSString *)replacement;
    
This method creates a parser that will match the sepcified regular expression, but can replace the captured text using a replacement template string, where $0-n can be used to represent the captured subexpressions from the regexp.

    - (instancetype)parserWithDescription:(NSString *)description;
    
This method can be used to override the description of an existing parser. So for example for a parser that matches the regular expression \d you might want to change the description from the default ""a string matching the pattern \d" to "a numeric digit". Note that FXParser objects are (mostly) immutable, so rather than modifying the parser, this will create and return a new parser object that matches the behaviour of the original but uses the new description.
    
    + (instancetype)forwardDeclaration;
    
Sometimes it is neccesary to create recursive rules, which can be difficult if you end up needing to refer to a parser before you've defined it. The `forwardDeclaration` constructor creates a "blank" parser that you can use within another parser definition on the understanding that you will supply the implementation using the `setImplementation:` method before you attempt to parse anything. Attempting to parse any text before the implementation has been set will throw an exception.
    
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
    
This method method takes an array of parsers and assembles them to form a single  parser. The resultant parser will succeed if *any* of supplied parsers match the input. If more than one of the parsers matches, the longest successful match will be used.
    
    - (instancetype)optional;
    
This method returns a new parser that will return success regardless of whether the original parser matches or not. This is useful for matching irrelevant content such as white space between tokens.
    
    - (instancetype)oneOrMore;
    
This method returns a new parser that will match a sequence of one or more of the original parser's required strings in sequence. If you wish to match a sequence of zero or more, you can chain this method with the `optional` modifier mentioned above.
    
    - (instancetype)separatedBy:(FXParser *)parser;
    
This method returns a new parser that will match a sequence of one or more of the original parser's required string separated by the supplied parser's required string. For example if the original parser matched a number, and the new parser argument matches a comma, the resultant parser would match a comma-delimited list of numbers.
    
    - (instancetype)surroundedBy:(FXParser *)parser;
    
This is a convenience method that returns a new parser that matches the original string preceeded and followed by the supplied parser's required string. This might be used to match a string in quotes for example, or a token surrounded by white space. It is equivalent to `[FXParser sequence:@[parser, self, parser]]`.
    
    - (instancetype)or:(FXParser *)parser;
    
This method returns a new parser that matches either the original parser's string or the supplied parser's string. It is equivalent to creating a new parser with `[FXParser oneOf:@[self, parser]].
    
    - (instancetype)then:(FXParser *)parser;

This method returns a new parser that matches the original parser's string followed by the supplied parser's string. It is equivalent to creating a new parser with `[FXParser sequence:@[self, parser]]`.


Value transformers
--------------------

These methods are used to convert the value returned in the FXParserResult object to a new value. This is useful if you want to control the form that your parsed data is converted to. Note that applying a value transform to a parser will discard any children of the original result.

    - (instancetype)withTransform:(FXParserValueTransform)transform;
    
This is the most flexible value transform function. It takes a block parameter that can be used to apply an arbitrary function to the value. The FXParserValueTransform block has the following signature:

    id (^FXParserValueTransform)(id value);
    
The predicate block takes an input value and returns an output value. How you get from one to the other is up to you, and the values can be of any object type.
    
    - (instancetype)withValueForKeyPath:(NSString *)keyPath;
    
Sometimes you want actually want a child property of a captured value, or the result of calling a method on the object (e.g. [string lowerCaseString]) - you can use the `withValueForKeyPath:` transform method for that. Specify a keypath that will be called on the value object and used to return the replacement value. 
    
    - (instancetype)withValue:(id)value;
    
Sometimes you just want to replace the captured value with a specific replacement value. This method returns the specified value instead of the original. 
    
    - (instancetype)discard;
    
Occasionally you will need to match some data that you are not interested in keeping (e.g. white space). Use the `discard` transform to remove it from the result value. 
    
    - (instancetype)array;
    
Sometimes you will need to match zero or more instances of a pattern, but you need the result to always be returned as an array even if it is an array containing only one object (or none). The `array` transform will inspect the value and either return it unmodified if it's already an array, wrap it in an array if it's a single object, or create a new empty array if the value is nil.
    
    - (instancetype)dictionary;
    
The `dictionary` transform will take an array value and treat it as an interleaved sequence of keys and values, which are gathered into an NSDictionary and returned. If the original value is nil, an empty dictionary will be returned. If the original value is not an array, or has an odd number of items, this method will throw an exception.
    
    - (instancetype)join:(NSString *)glue;
    
This method takes an array of values and "glues" them together with the supplied string as a separator using NSArray's `componentsJoinedByString:` method.


FXParserResult
------------------

The FXParserResult encapsulates the result of applying a parser to some input. It has the following properties:

    @property (nonatomic, readonly) BOOL success;
    
A boolean indicating whether parsing was successful.
    
    @property (nonatomic, readonly) id value;
    
The value returned after parsing the input. This can be either a single value or an array of results.
    
    @property (nonatomic, readonly) NSRange remaining;
    
The remaining range of the input string that was not consumed by the parsing process. Note that for an FXParser to succeed, it does not neccesarily have to have consumed all of the available input. If you wish to treat leftover input as an error, you can either enforce this as a custom rule implemented using a custom FXParserBlock, or just check the result to see if the remaining.length > 0. 
    
    @property (nonatomic, readonly) NSArray *children;
    
This is an array (or tree, since each child may have children of its own) of sub-results created by nested FXParsers within the main parser. If the value parsed was composed of smaller tokens or structures, you can retrieve information about them by inspecting this value. For example, you can use the `remaining` values of the children to calculate the positions of the child values within the original string. In the event of an unsuccessful parsing, this value will contain all of the successfully matched sub-results up until the point of failure, which may be useful for error recovery.
    
    @property (nonatomic, readonly) NSString *expected;
    
For a successful parsing this value will be nil. If parsing fails, this value will contain a human readable (if terse) description of the expected input at the point of failure.
    
You can construct an FXParserResult using one of the following methods:

    + (instancetype)successWithValue:(id)value remaining:(NSRange)remaining;
    
This is used to generate an FXParserResult that represents a successful parsing operation. The value is the resultant parsed value, the remaining range is the range of the input string that was not consumed. 
    
    + (instancetype)successWithChildren:(NSArray *)children remaining:(NSRange)remaining;
    
This is used to generate an FXParserResult that represents a successful parsing operation where an array of results has been matched (as opposed to a single value). Whilst you could return this array of results as an array of values using the `successWithValue:remaining:` method, this has two disadvantages:

1. The context of the individual results (e.g. their position within the string) is not preserved.

2. Nested rules will produce nested arrays of values instead of a single concatenated array, which may be harder to work with (note that if you want nested arrays of values in the results, you can use the `array` value transform method to redefine an array of results as a single array-type value).
    
    + (instancetype)failureWithChildren:(NSArray *)children expected:(NSString *)description remaining:(NSRange)remaining;
    
This method is used to generate an FXParserResult that represents a failed parsing operation. Any successful sub-parsing results (e.g. if the parser found 4 strings but was expecting 5) should be passed as the children parameter. For results that do not have any children, pass nil. The expected string is a description of the value that was expected. In most cases this is just the `[parser description]` value. The remaining value will be the range of the unconsumed part of the string, which should match the input range in most cases if the children value is nil, or should match the last child's `remaining` property if not.


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
        return [[self regexp:@"-?[0-9]*\\.?[0-9]+"] parserWithDescription:@"a number"];
    }
    
    @end
    
Q. I need to return additional information in my result, such as the range of the originally matched string, or some additional contextual metadata. How can I add additional data to the FXParserResult?

A. The only real option is to subclass FXParserResult and add a new constructor that takes additional values (or make the setters for your new values public). However, if you are using a custom FXParserResult subclass you won't be able to use any of the built-in FXParser constructors, combinators or value transforms except for the `parserWithBlock:description:` designated constructor, as these will all return standard FXParserResult instances instead of your subclass.

You may be able to subclass FXParser and override all the methods that use FXParserResults to make them return your subclass instead, but this is not a very future-proof solution if additional constructors or combinators are added in future.

A better approach is probably to post-process the FXParserResult returned by your parser. For example, by iterating over a result and all of its children and comparing their `remaining` values to the original input range. Given the range of the original input string it should then be possible to create any additional data about the input that you require. If you have a usage scenario that this doesn't cover, file a feature request on the FXParser github page.

Q. I need to implement an operator precedence system so that I can parse arithemetic logic.

A. The solution here would be to subclass FXParser and add a precedence property and a method to set it. You will also need to override the `oneOf:` constructor and modify its precedence logic - which is currently based on the length of the string consumed - to make use of your new property instead. An official operator precedence system will most likely be added in a future release of FXParser.