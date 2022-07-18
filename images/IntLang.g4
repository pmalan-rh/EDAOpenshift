grammar IntLang;

@parser::header
{
// DO NOT MODIFY - generated from IntLang.g4 using "mx create-sl-parser"

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.oracle.truffle.api.source.Source;
import com.oracle.truffle.api.RootCallTarget;
import com.pietersmalan.integration.language.IntLang;
import com.pietersmalan.integration.language.lang.ILNodeFactory;
import com.pietersmalan.integration.language.lang.ILParseError;

}

@lexer::header
{
// DO NOT MODIFY - generated from IntLang.g4 using "mx create-sl-parser"
}

@parser::members
{
private ILNodeFactory factory;
private Source source;

private static final class BailoutErrorListener extends BaseErrorListener {
    private final Source source;
    BailoutErrorListener(Source source) {
        this.source = source;
    }
    @Override
    public void syntaxError(Recognizer<?, ?> recognizer, Object offendingSymbol, int line, int charPositionInLine, String msg, RecognitionException e) {
        String location = "-- line " + line + " col " + (charPositionInLine + 1) + ": ";
        throw new ILParseError(source, line, charPositionInLine + 1, offendingSymbol == null ? 1 : ((Token) offendingSymbol).getText().length(), String.format("Error(s) parsing script:%n" + location + msg));
    }
}

public void SemErr(Token token, String message) {
    int col = token.getCharPositionInLine() + 1;
    String location = "-- line " + token.getLine() + " col " + col + ": ";
    throw new ILParseError(source, token.getLine(), col, token.getText().length(), String.format("Error(s) parsing script:%n" + location + message));
}

public static Map<String, RootCallTarget> parseSL(IntLang language, Source source) {
    IntLangLexer lexer = new IntLangLexer(CharStreams.fromString(source.getCharacters().toString()));
    IntLangParser parser = new IntLangParser(new CommonTokenStream(lexer));
    lexer.removeErrorListeners();
    parser.removeErrorListeners();
    BailoutErrorListener listener = new BailoutErrorListener(source);
    lexer.addErrorListener(listener);
    parser.addErrorListener(listener);
    parser.factory = new ILNodeFactory(language, source);
    parser.source = source;
    parser.integration();
    return parser.factory.getAllFunctions();
}
}


integration
    : integrationHeading function* trigger* EOF
    ;

integrationHeading
    : integrationProperties
    ;

integrationProperties
    : intID intName intVers intPackage? intProject?
    ;

intID:
     'INTEGRATION' string
    ;

 intName:
      'NAME' string
     ;

 intVers:
     'VERSION' string
     ;

  intPackage:
     'PACKAGE' string
     ;

   intProject:
     'PROJECT' string
    ;

string
   : STRING_LITERAL
   ;

function
:
'function'
IDENTIFIER
s='('
                                                { factory.startFunction($IDENTIFIER, $s); }
(
    IDENTIFIER                                  { factory.addFormalParameter($IDENTIFIER); }
    (
        ','
        IDENTIFIER                              { factory.addFormalParameter($IDENTIFIER); }
    )*
)?
')'
body=block[false]                               { factory.finishFunction($body.result); }
;

trigger
:
'trigger'
IDENTIFIER

(
'schedule' NUMERIC_LITERAL ('ms'|'m'|'h'|'days')
)?

body=block[false]                               { factory.finishFunction($body.result); }
;

block [boolean inLoop] returns [ILStatementNode result]
   :                                    { factory.startBlock();
        List<ILStatementNode> body = new ArrayList<>();}
    s='{'
    (
        statement[inLoop]              { body.add($statement.result); }
    )*
    e='}'
                                       { $result = factory.finishBlock(body, $s.getStartIndex(), $e.getStopIndex() - $s.getStartIndex() + 1); }
   ;

statement [boolean inLoop] returns [ILStatement result]
    :
    (
    while_statement                            { $result = $while_statement.result; }
    |
    ifStatement[inLoop]                        { $result = $ifStatement.result; }
    |
    return_statement                            { $result = $return_statement.result; }
    |
    expression ';'                              { $result = $expression.result; }
    )
    ;

ifStatement [inLoop] returns [ILStatement result]
   :
   i='if'
   '('
   condition=expression
   ')'

   then=block[inLoop]       { SLStatementNode elsePart = null; }
   (
   'else'
   block[inLoop]            { elsePart = $block.result; }
   )?                       { $result = factory.createIf($i, $condition.result, $then.result, elsePart); }

   ;

while_statement returns [SLStatementNode result]
    :
    w='while'
    '('
        condition=expression
    ')'
    body=block[true]                                { $result = factory.createWhile($w, $condition.result, $body.result); }
    ;


expression returns [SLExpressionNode result]
:
logic_term                                      { $result = $logic_term.result; }
(
    op='||'
    logic_term                                  { $result = factory.createBinary($op, $result, $logic_term.result); }
)*
;


logic_term returns [SLExpressionNode result]
:
logic_factor                                    { $result = $logic_factor.result; }
(
    op='&&'
    logic_factor                                { $result = factory.createBinary($op, $result, $logic_factor.result); }
)*
;


logic_factor returns [SLExpressionNode result]
:
arithmetic                                      { $result = $arithmetic.result; }
(
    op=('<' | '<=' | '>' | '>=' | '==' | '!=' )
    arithmetic                                  { $result = factory.createBinary($op, $result, $arithmetic.result); }
)?
;


arithmetic returns [SLExpressionNode result]
:
term                                            { $result = $term.result; }
(
    op=('+' | '-')
    term                                        { $result = factory.createBinary($op, $result, $term.result); }
)*
;


term returns [SLExpressionNode result]
:
factor                                          { $result = $factor.result; }
(
    op=('*' | '/')
    factor                                      { $result = factory.createBinary($op, $result, $factor.result); }
)*
;


factor returns [SLExpressionNode result]
:
(
    IDENTIFIER                                  { SLExpressionNode assignmentName = factory.createStringLiteral($IDENTIFIER, false); }
    (
        member_expression[null, null, assignmentName] { $result = $member_expression.result; }
    |
                                                { $result = factory.createRead(assignmentName); }
    )
|
    STRING_LITERAL                              { $result = factory.createStringLiteral($STRING_LITERAL, true); }
|
    NUMERIC_LITERAL                             { $result = factory.createNumericLiteral($NUMERIC_LITERAL); }
|
    s='('
    expr=expression
    e=')'                                       { $result = factory.createParenExpression($expr.result, $s.getStartIndex(), $e.getStopIndex() - $s.getStartIndex() + 1); }
)
;


member_expression [SLExpressionNode r, SLExpressionNode assignmentReceiver, SLExpressionNode assignmentName] returns [SLExpressionNode result]
:                                               { SLExpressionNode receiver = r;
                                                  SLExpressionNode nestedAssignmentName = null; }
(
    '('                                         { List<SLExpressionNode> parameters = new ArrayList<>();
                                                  if (receiver == null) {
                                                      receiver = factory.createRead(assignmentName);
                                                  } }
    (
        expression                              { parameters.add($expression.result); }
        (
            ','
            expression                          { parameters.add($expression.result); }
        )*
    )?
    e=')'
                                                { $result = factory.createCall(receiver, parameters, $e); }
|
    '='
    expression                                  { if (assignmentName == null) {
                                                      SemErr($expression.start, "invalid assignment target");
                                                  } else if (assignmentReceiver == null) {
                                                      $result = factory.createAssignment(assignmentName, $expression.result);
                                                  } else {
                                                      $result = factory.createWriteProperty(assignmentReceiver, assignmentName, $expression.result);
                                                  } }
|
    '.'                                         { if (receiver == null) {
                                                       receiver = factory.createRead(assignmentName);
                                                  } }
    IDENTIFIER
                                                { nestedAssignmentName = factory.createStringLiteral($IDENTIFIER, false);
                                                  $result = factory.createReadProperty(receiver, nestedAssignmentName); }
|
    '['                                         { if (receiver == null) {
                                                      receiver = factory.createRead(assignmentName);
                                                  } }
    expression
                                                { nestedAssignmentName = $expression.result;
                                                  $result = factory.createReadProperty(receiver, nestedAssignmentName); }
    ']'
)
(
    member_expression[$result, receiver, nestedAssignmentName] { $result = $member_expression.result; }
)?
;


return_statement returns [SLStatementNode result]
:
r='return'                                      { SLExpressionNode value = null; }
(
    expression                                  { value = $expression.result; }
)?                                              { $result = factory.createReturn($r, value); }
';'
;


// lexer

WS : [ \t\r\n\u000C]+ -> skip;
COMMENT : '/*' .*? '*/' -> skip;
LINE_COMMENT : '//' ~[\r\n]* -> skip;

fragment LETTER : [A-Z] | [a-z] | '_' | '$';
fragment NON_ZERO_DIGIT : [1-9];
fragment DIGIT : [0-9];
fragment HEX_DIGIT : [0-9] | [a-f] | [A-F];
fragment OCT_DIGIT : [0-7];
fragment BINARY_DIGIT : '0' | '1';
fragment TAB : '\t';
fragment STRING_CHAR : ~('"' | '\\' | '\r' | '\n');

IDENTIFIER : LETTER (LETTER | DIGIT)*;
STRING_LITERAL : '"' STRING_CHAR* '"';
NUMERIC_LITERAL : '0' | NON_ZERO_DIGIT DIGIT*;