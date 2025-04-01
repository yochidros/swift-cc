import os

nonisolated(unsafe) var userInput = ""

let args = CommandLine.arguments

guard args.count == 2 else {
  print("\(args[0]): invalid number of arguments")
  exit(1)
}

let str = args[1]
userInput = str

var head = tokenize(str)
// print(head)
var n = makeProgram(&head)
// print(n)

print(".global _main")
print("_main:")

/* prologue
stp     fp, lr, [sp, #-16]!   // push fp と lr（16バイト確保）
mov     fp, sp                // 新しいフレームポインタ設定
sub     sp, sp, #208          // ローカル変数用のスタック確保
*/

print("\t// prologue")
printInstruction(op: "stp", args: "fp", "lr", "[sp, #-16]!", comment: "push fp and lr")
printInstruction(op: "mov", args: "fp", "sp", comment: "set new frame pointer")
// 16の倍数にしないとアライメント境界が不正になる
printInstruction(op: "sub", args: "sp", "sp", "#224", comment: "allocate stack for local variables")
print()

var contxt = CodeGenContext()
for var node in n {
  print("\t// \(node)")
  generate(&node, context: &contxt, isRoot: true)
  // printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
  print()
}


/* epilogue
mov sp, fp
ldp fp, lr, [sp], #16
*/

print("\t// epilogue")
printInstruction(op: "mov", args: "sp", "fp", comment: "restore sp")
printInstruction(op: "ldp", args: "fp", "lr", "[sp], #16", comment: "pop fp and lr")
print("\tret")
exit(0)
