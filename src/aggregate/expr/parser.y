
%name RSExprParser_Parse

%left AND OR NOT.
%left EQ NE LT LE GT GE.

%left PLUS MINUS.
%left DIVIDE TIMES MOD POW.

%right LP.
%left RP.

%left PROPERTY.
%right SYMBOL.
%left STRING.
%left NUMBER.
%right ARGLIST.

%extra_argument { RSExprParseCtx *ctx }

%token_type { RSExprToken }
%default_type {RSExpr *}
%default_destructor {RSExpr_Free($$); }

%type number {double}
%destructor number {} 

%type arglist { RSArgList * }
%destructor arglist {RSArgList_Free($$); }

%include {
#include "token.h"
#include "expression.h"
#include "parser.h"

}

%syntax_error {  

    asprintf(&ctx->errorMsg, "Syntax error at offset %d near '%.*s'", TOKEN.pos, TOKEN.len, TOKEN.s);
    ctx->ok = 0;
}   
   
program ::= expr(A). { ctx->root = A; }

expr(A) ::= LP expr(B) RP. { A = B; }
expr(A) ::= expr(B) PLUS expr(C). { A = RS_NewOp('+', B, C); }
expr(A) ::= expr(B) DIVIDE expr(C). {  A = RS_NewOp('/', B, C); }
expr(A) ::= expr(B) TIMES expr(C). {  A = RS_NewOp('*', B, C);}
expr(A) ::= expr(B) MINUS expr(C). {  A = RS_NewOp('-', B, C); }
expr(A) ::= expr(B) POW expr(C). {  A = RS_NewOp('^', B, C); }
expr(A) ::= expr(B) MOD expr(C). { A = RS_NewOp('%', B, C); }

// Logical predicates
expr(A) ::= expr(B) EQ expr(C). { A = RS_NewPredicate(RSCondition_Eq, B, C); }
expr(A) ::= expr(B) NE expr(C). { A = RS_NewPredicate(RSCondition_Ne, B, C); }
expr(A) ::= expr(B) LT expr(C). { A = RS_NewPredicate(RSCondition_Lt, B, C); }
expr(A) ::= expr(B) LE expr(C). { A = RS_NewPredicate(RSCondition_Le, B, C); }
expr(A) ::= expr(B) GT expr(C). { A = RS_NewPredicate(RSCondition_Gt, B, C); }
expr(A) ::= expr(B) GE expr(C). { A = RS_NewPredicate(RSCondition_Ge, B, C); }
expr(A) ::= expr(B) AND expr(C). { A = RS_NewPredicate(RSCondition_And, B, C); }
expr(A) ::= expr(B) OR expr(C). { A = RS_NewPredicate(RSCondition_Or, B, C); }
expr(A) ::= NOT expr(B). { A = RS_NewPredicate(RSCondition_Not, B, NULL); }


expr(A) ::= STRING(B). { A =  RS_NewStringLiteral((char*)B.s, B.len); }
expr(A) ::= number(B). { A = RS_NewNumberLiteral(B); }

number(A) ::= NUMBER(B). { A = B.numval; }
number(A) ::= MINUS NUMBER(B). { A = -B.numval; }

expr(A) ::= PROPERTY(B). { A = RS_NewProp(B.s, B.len); }
expr(A) ::= SYMBOL(B) LP arglist(C) RP. {
    RSFunction cb = RSFunctionRegistry_Get(B.s, B.len);
    if (!cb) {
        asprintf(&ctx->errorMsg, "Unknown function name '%.*s'", B.len, B.s);
        ctx->ok = 0;
        A = NULL; 
    } else {
         A = RS_NewFunc(B.s, B.len, C, cb);
    }
}

expr(A) ::= SYMBOL(B) . {
    if (B.len == 4 && !strncmp(B.s, "NULL", 4)) {
        A = RS_NewNullLiteral();
    } else {
        asprintf(&ctx->errorMsg, "Unknown symbol '%.*s'", B.len, B.s);
        ctx->ok = 0;
        A = NULL; 
    }
}

arglist(A) ::= . [ARGLIST] { A = RS_NewArgList(NULL); }
arglist(A) ::= expr(B) . [ARGLIST] { A = RS_NewArgList(B); }
arglist(A) ::= arglist(B) COMMA expr(C) . [ARGLIST] { 
    A = RSArgList_Append(B, C);
}