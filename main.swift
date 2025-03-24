
import Foundation

let args = CommandLine.arguments

guard args.count == 2 else {
    print("\(args[0]): invalid number of arguments")
    exit(1)
}

print(".global _main")
print("_main:")
print(" mov w0, #\(args[1])")
print(" ret")

exit(0)
