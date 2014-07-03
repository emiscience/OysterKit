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

//Should be private and class variables
let decimalDigitString = "0123456789"
let hexDigitString = decimalDigitString+"ABCDEFabcdef"
let puncuationString = "!\"#$%&'()*+,\\-./:;<=>?@[]^_`{|}~"
let blankString = " \t"
let whiteSpaceString = " \t\r\n"
let lowerCaseLetterString = "abcdefghijklmnopqrstuvwxyz"
let upperCaseLetterString = lowerCaseLetterString.uppercaseString
let eotString = "\x004"

class OysterKit{
    
    //Public
    class var decimalDigit:TokenizationState{
        return Char(from: decimalDigitString).token("digit")
    }
    
    class var hexDigit:TokenizationState{
        return Char(from: hexDigitString).token("xdigit")
    }
    
    class var punctuation:TokenizationState{
        return Char(from: puncuationString).token("punct")
    }
    
    class var eot:TokenizationState{
        return Char(from:"\u0004").token("end")
    }
    
    class var blank:TokenizationState{
        return Char(from: blankString).token("blank")
    }
    
    class var whiteSpace:TokenizationState{
        return Char(from: whiteSpaceString).token("space")
    }
    
    class var lowercaseLetter:TokenizationState{
        return Char(from: lowerCaseLetterString).token("lower")
    }
    
    class var uppercaseLetter:TokenizationState{
        return Char(from:upperCaseLetterString).token("upper")
    }
    
    class var letter:TokenizationState{
        return Char(from: lowerCaseLetterString+upperCaseLetterString).token("alpha")
    }
    
    class var letterOrDigit:TokenizationState{
        return Char(from: lowerCaseLetterString+upperCaseLetterString+decimalDigitString).token("alnum")
    }
    
    class var wordCharacter:TokenizationState{
        return Char(from: lowerCaseLetterString+upperCaseLetterString+decimalDigitString+"_").token("word")
    }
        
    class var number:TokenizationState{
        let decimalPointChain = Char(from: ".").sequence(
            Repeat(state: decimalDigit).token("float"),
            Char(from: "eE").branch(
                Repeat(state: decimalDigit).token("float"),
                Char(from: "+-").sequence(
                    Repeat(state: decimalDigit).token("float")
                    )
                )
            )

        return Branch().branch(
            Repeat(state: decimalDigit).token("integer").branch(decimalPointChain),
            Char(from: "+-").token(OperatorToken.createToken).sequence(
                Repeat(state: decimalDigit).token("integer").branch(
                    decimalPointChain
                    )
                )
            )
    }
    
    class var word:TokenizationState{
        return Repeat(state: wordCharacter).token("word")
    }
    
    class var blanks:TokenizationState{
        return Repeat(state: blank).token("blank")
    }
    
    class var whiteSpaces:TokenizationState{
        return Repeat(state: whiteSpace).token("whitespace")
    }
    
    
}