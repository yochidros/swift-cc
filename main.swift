import Foundation

func swiftStrtol(_ str: String, base: Int = 10) -> (value: Int?, rest: Substring) {
	var index = str.startIndex
	while index != str.endIndex {
		let prefix = str[str.startIndex ... index]
		if Int(prefix, radix: base) == nil {
			break
		}
		index = str.index(after: index)
	}

	let numberPart = str[str.startIndex ..< index]
	let rest = str[index...]
	let value = Int(numberPart, radix: base)

	return (value, rest)
}

func printInstruction(op: String, args: String...) {
	print("\t\(op)\t\(args.joined(separator: ", "))")
}

let args = CommandLine.arguments

guard args.count == 2 else {
	print("\(args[0]): invalid number of arguments")
	exit(1)
}

var str = args[1]

print(".global _main")
print("_main:")

var rest: Substring?
let (value, _r) = swiftStrtol(str)
rest = _r
if let value {
	printInstruction(op: "mov", args: "w0", "#\(value)")
}

while var r = rest {
	guard let op = r.popFirst() else { break }
	let (value, _r) = swiftStrtol(String(r))
	rest = _r
	guard let value else { break }
	switch op {
	case "+":
		printInstruction(op: "add", args: "w0", "w0", "#\(value)")
	case "-":
		printInstruction(op: "sub", args: "w0", "w0", "#\(value)")
	default:
		fatalError("unknown operator: \(op)")
	}
}

print("\tret")

exit(0)
