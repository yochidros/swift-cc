import Foundation

enum TokenKind: String {
	case number
	case reserved
	case eof
}
		}
	}


class Token: CustomDebugStringConvertible {
	let kind: TokenKind
	var next: Token?

	var number: Int?
	let str: Substring

	init(kind: TokenKind, next: Token? = nil, number: Int? = nil, str: Substring) {
		self.kind = kind
		self.next = next
		self.number = number
		self.str = str
	}

	var debugDescription: String {
		if let next {
			return "\(kind)(\(str))\n -> \(next)"
		} else {
			return "\(kind)(\(str))"
		}
	}
}

func printInstruction(op: String, args: String...) {
	print("\t\(op)\t\(args.joined(separator: ", "))")
}


}

func consume(op: Substring) -> Bool {
	if tokens?.kind != .reserved || tokens?.str != op {
		return false
	}
	tokens = tokens?.next
	return true
}

func expect(op: Substring) {
	if tokens?.kind != .reserved || tokens?.str != op {
		fatalError("unexpected token: \(op)")
	}
	tokens = tokens?.next
}

func expectNumber() -> Int {
	guard let num = tokens?.number, tokens?.kind == .number else {
		fatalError("not number")
	}
	tokens = tokens?.next
	return num
}

func atEOF() -> Bool {
	return tokens?.kind == .eof
}

@discardableResult
func newToken(cur: Token, kind: TokenKind, str: Substring) -> Token {
	let new = Token(kind: kind, str: str)
	cur.next = new
	return new
}

func tokenize(_ str: String) -> Token {
	let head: Token = .init(kind: .eof, str: "")
	var index = str.startIndex
	var cur = head

	while index != str.endIndex {
		let c = str[index]
		if c.isWhitespace {
			index = str.index(after: index)
			continue
		}

		if str[index] == "+" || str[index] == "-" {
			let op = str[index ... index]
			let tok = Token(kind: .reserved, str: op)
			cur.next = tok
			cur = tok
			index = str.index(after: index)
			continue
		}

		if c.isNumber {
			let start = index
			while index != str.endIndex && str[index].isNumber {
				index = str.index(after: index)
			}
			let numStr = str[start ..< index]
			let num = Int(numStr)
			let tok = newToken(cur: cur, kind: .number, str: numStr)
			tok.number = num
			cur.next = tok
			cur = tok
			continue
		}
		fatalError("failed tokenize \(str[index])")
	}
	cur.next = Token(kind: .eof, str: "")
	return head.next!
}

var tokens: Token!

func main() {
	let args = CommandLine.arguments

	guard args.count == 2 else {
		print("\(args[0]): invalid number of arguments")
		exit(1)
	}

	let str = args[1]

	print(".global _main")
	print("_main:")

	tokens = tokenize(str)

	printInstruction(op: "mov", args: "w0", "#\(expectNumber())")

	while !atEOF() {
		if consume(op: "+") {
			printInstruction(op: "add", args: "w0", "w0", "#\(expectNumber())")
			continue
		}
		expect(op: "-")
		printInstruction(op: "sub", args: "w0", "w0", "#\(expectNumber())")
	}
	print("\tret")
	exit(0)
}

main()
