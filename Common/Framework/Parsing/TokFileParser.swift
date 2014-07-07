/*
Copyright (c) 2014, RED When Excited
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

class TokenizerFile : Tokenizer {
    
    
    init(){
        super.init()
        //Eventually this will be it's own file
        
        
        
        self.branch(
            Delimited(delimiter: "\"", states:
                Repeat(state:Branch().branch(
                    Char(from:"\\").branch(
                        Char(from:"trn\"\\").token("character")
                    ),
                    Char(except: "\"").token("character")
                    ), min: 1, max: nil).token("Char")
                ).token("quote"),
            Delimited(delimiter: "'", states:
                Repeat(state:Branch().branch(
                    Char(from:"\\").branch(
                        Char(from:"'\\").token("character")
                    ),
                    Char(except: "'").token("character")
                    ), min: 1).token("delimiter")
                ).token("single-quote"),
            Char(from: "!").token("not"),
            Char(from: "-").sequence(
                Char(from:">").token("token")
            ),
            Char(from:".").token("then"),
            Char(from:"{").token("start-branch"),
            Char(from:"}").token("end-branch"),
            Char(from:"(").token("start-repeat"),
            Char(from:")").token("end-repeat"),
            Char(from:"<").token("start-delimited"),
            Char(from:">").token("end-delimited"),
            Char(from:",").token("comma"),
            OysterKit.number,
            //            Char(from:lowerCaseLetterString+upperCaseLetterString+decimalDigitString+"-_").token("word"),
            OysterKit.variableName,
            OysterKit.whiteSpaces,
            Char(except: "\x04")
        )
    }
    
}


class State:Token{
    var state : TokenizationState
    
    init(state:TokenizationState){
        self.state = state
        super.init(name: "state",withCharacters: "")
    }
    
    override var description:String {
        return state.description
    }
}

class Operator : Token {
    init(characters:String){
        super.init(name: "operator", withCharacters: characters)
    }

    func applyTo(token:Token, parser:_privateTokFileParser)->Token?{
        return nil
    }
}

class EmitTokenOperator : Operator {
    override func applyTo(token: Token, parser:_privateTokFileParser) -> Token? {
        //TODO: Probably an error, should report that
        if !parser.hasTokens() {
            parser.error = "Expected a state to assign the token to"
            return nil
        }
        
        var topToken = parser.popToken()!
        
        if let stateToken = topToken as? State {
            stateToken.state.token(token.characters)
            return stateToken
        } else {
            parser.error = "Only states can emit tokens"
            parser.pushToken(topToken)
        }
        
        return nil
    }
}

class ChainStateOperator : Operator {
}

class _privateTokFileParser:StackParser{
    var invert:Bool = false
    var error:String?
    
    func invokeOperator(onToken:Token){
        if hasTokens() {
            if topToken()?.name.hasPrefix("operator") {
                var operator = popToken()! as Operator
                if let newToken = operator.applyTo(onToken, parser: self) {
                    pushToken(newToken)
                }
            } else {
                error = "Expected an operator"
                pushToken(onToken)
            }
        } else {
            error = "Expected an operator, there were none"
            pushToken(onToken)
        }
    }
    
    func popTo(tokenNamed:String)->Array<Token> {
        var tokenArray = Array<Token>()
        
        var token = popToken()
        
        if token == nil {
            error = "Expected \(tokenNamed), but there were none"
            return tokenArray
        }
        
        while (token!.name != tokenNamed) {
            if let nextToken = token{
                tokenArray.append(nextToken)
            } else {
                error = "Expected \(tokenNamed)"
                return tokenArray
            }
            token = popToken()
            if token == nil {
                error = "Expected \(tokenNamed), but there were none"
                return Array<Token>()
            }
        }
        
        //Now we have an array of either states, or chains of states
        //and the chains need to be unwound and entire array reversed
        var finalArray = Array<Token>()
        var operator : ChainStateOperator?
        
        for token in tokenArray {
            if let stateToken = token as? State {
                if operator {
                    //The last state needs to be removed, 
                    //chained to this state, 
                    ///and this state added to final
                    if finalArray.count == 0 {
                        error = "Incomplete state definition"
                        return Array<Token>()
                    }
                    var lastToken = finalArray.removeLast()
                    if let lastStateToken = lastToken as? State {
                        stateToken.state.branch(lastStateToken.state)
                        operator = nil
                    } else {
                        error = "Only states can emit tokens"
                        return Array<Token>()
                    }
                }
                finalArray.append(stateToken)
            } else if token is ChainStateOperator {
                operator = token as? ChainStateOperator
            } else {
                //It's just a parameter
                finalArray.append(token)
            }
        }
        
        return finalArray.reverse()
    }
    
    func endBranch(){
        
        var branch = Branch()
        
        for token in popTo("start-branch"){
            if let stateToken = token as? State {
                branch.branch(stateToken.state)
            }
        }
        
        pushToken(State(state: branch))
    }
    
    func endRepeat(){
        var parameters = popTo("start-repeat")
        
        if (parameters.count == 0){
            error="At least a state is required"
            return
        }
        
        if !(parameters[0] is State) {
            error = "Expected a state"
            return
        }
        
        var minimum = 1
        var maximum : Int? = nil
        var repeatingState = parameters[0] as State
        
        if parameters.count > 1 {
            if var minimumNumberToken = parameters[1] as? NumberToken {
                minimum = Int(minimumNumberToken.numericValue)
                if parameters.count > 2 {
                    if var maximumNumberToken = parameters[2] as? NumberToken {
                        maximum = Int(maximumNumberToken.numericValue)
                    } else {
                        error = "Expected a number"
                        return
                    }
                }
            } else {
                error = "Expected a number"
                return
            }
        }
        
        var repeat = Repeat(state: repeatingState.state, min: minimum, max: maximum)
        
        pushToken(State(state:repeat))
    }
    
    func endDelimited(){
        var parameters = popTo("start-delimited")
        
        if parameters.count < 2 || parameters.count > 3{
            error = "At least two parameters are required for a delimited state"
            return
        }
        
        
        if parameters[0].name != "delimiter" {
            error = "At least one delimiter must be specified"
            return
        }

        var openingDelimiter = parameters[0].characters
        var closingDelimiter = openingDelimiter
        
        if parameters.count == 3{
            if parameters[1].name != "delimiter" {
                error = "Expected delimiter character as second parameter"
                return
            }
            closingDelimiter = parameters[1].characters
        }
        
        openingDelimiter = unescapeDelimiter(openingDelimiter)
        closingDelimiter = unescapeDelimiter(closingDelimiter)
        
        if let delimitedStateToken = parameters[parameters.endIndex-1] as? State {
            var delimited = Delimited(open: openingDelimiter, close: closingDelimiter, states: delimitedStateToken.state)
            
            pushToken(State(state:delimited))
        } else {
            error = "Final parameter must be a state"
            return
        }
    }
    
    func unescapeChar(characters:String)->String{
        if countElements(characters) == 1 {
            return characters
        }
        
        let simpleTokenizer = Tokenizer()
        simpleTokenizer.branch(
                OysterKit.eot.token("ignore"),
                Char(from:"\\").branch(
                    Char(from:"\\").token("backslash"),
                    Char(from:"\"").token("quote"),
                    Char(from:"n").token("newline"),
                    Char(from:"r").token("return"),
                    Char(from:"t").token("tab")
                ),
                Char(except: "\\").token("character")
            )
        
        var output = ""
        for token in simpleTokenizer.tokenize(characters){
            switch token.name {
            case "return":
                output+="\r"
            case "tab":
                output+="\t"
            case "newline":
                output+="\n"
            case "quote":
                output+="\""
            case "backslash":
                output+="\\"
            case "ignore":
                output += ""
            default:
                output+=token.characters
            }
        }
        
        return output
    }
    
    func unescapeDelimiter(character:String)->String{
        if character == "\\'" {
            return "'"
        } else if character == "\\\\" {
            return "\\"
        }
        return character
    }
    
    override func parse(token: Token) -> Bool {
        
        if error {
            return false
        }
        
        if __okDebug {
            println(">Processing: \(token)")
        }
        switch token.name {
        case "not":
            invert = true
        case "Char":
            let state = invert ? Char(except: unescapeChar(token.characters)) : Char(from:unescapeChar(token.characters))
            let symbol = State(state: state)
            pushToken(symbol)
            invert = false
        case "then":
            pushToken(ChainStateOperator(characters:token.characters))
        case "token":
            pushToken(EmitTokenOperator(characters:token.characters))
        case "delimiter":
            pushToken(token)
        case "integer":
            pushToken(NumberToken(usingToken: token))
        case "variable":
            invokeOperator(token)
        case "end-repeat":
            endRepeat()
        case "end-branch":
            endBranch()
        case "end-delimited":
            endDelimited()
        case let name where name.hasPrefix("start"):
            invert = false
            pushToken(token)
        default:
            return true
        }
        
        return true
    }

    func parseState(string:String) ->TokenizationState {
        TokenizerFile().tokenize(string,parse)
        
        var tokenizer = Tokenizer()
        
        if let rootState = popToken() as? State {
            return rootState.state
        } else {
            error = "Could not create root state"
            return Branch()
        }
    }
    
    func parse(string: String) -> Tokenizer {
        var tokenizer = Tokenizer()
        
        tokenizer.branch(parseState(string))
        
        return tokenizer
    }
}