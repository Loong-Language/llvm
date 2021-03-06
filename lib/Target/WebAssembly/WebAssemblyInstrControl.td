//===- WebAssemblyInstrControl.td-WebAssembly control-flow ------*- tablegen -*-
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
///
/// \file
/// WebAssembly control-flow code-gen constructs.
///
//===----------------------------------------------------------------------===//

let Defs = [ARGUMENTS] in {

let isBranch = 1, isTerminator = 1, hasCtrlDep = 1 in {
// The condition operand is a boolean value which WebAssembly represents as i32.
def BR_IF : I<(outs), (ins bb_op:$dst, I32:$cond),
              [(brcond I32:$cond, bb:$dst)],
               "br_if   \t$dst, $cond", 0x0d>;
let isCodeGenOnly = 1 in
def BR_UNLESS : I<(outs), (ins bb_op:$dst, I32:$cond), []>;
let isBarrier = 1 in {
def BR   : I<(outs), (ins bb_op:$dst),
             [(br bb:$dst)],
             "br      \t$dst", 0x0c>;
} // isBarrier = 1
} // isBranch = 1, isTerminator = 1, hasCtrlDep = 1

} // Defs = [ARGUMENTS]

def : Pat<(brcond (i32 (setne I32:$cond, 0)), bb:$dst),
          (BR_IF bb_op:$dst, I32:$cond)>;
def : Pat<(brcond (i32 (seteq I32:$cond, 0)), bb:$dst),
          (BR_UNLESS bb_op:$dst, I32:$cond)>;

let Defs = [ARGUMENTS] in {

// TODO: SelectionDAG's lowering insists on using a pointer as the index for
// jump tables, so in practice we don't ever use BR_TABLE_I64 in wasm32 mode
// currently.
// Set TSFlags{0} to 1 to indicate that the variable_ops are immediates.
// Set TSFlags{1} to 1 to indicate that the immediates represent labels.
let isTerminator = 1, hasCtrlDep = 1, isBarrier = 1 in {
def BR_TABLE_I32 : I<(outs), (ins I32:$index, variable_ops),
                     [(WebAssemblybr_table I32:$index)],
                     "br_table \t$index", 0x0e> {
  let TSFlags{0} = 1;
  let TSFlags{1} = 1;
}
def BR_TABLE_I64 : I<(outs), (ins I64:$index, variable_ops),
                     [(WebAssemblybr_table I64:$index)],
                     "br_table \t$index"> {
  let TSFlags{0} = 1;
  let TSFlags{1} = 1;
}
} // isTerminator = 1, hasCtrlDep = 1, isBarrier = 1

// This is technically a control-flow instruction, since all it affects is the
// IP.
def NOP : I<(outs), (ins), [], "nop", 0x01>;

// Placemarkers to indicate the start or end of a block or loop scope.
// These use/clobber VALUE_STACK to prevent them from being moved into the
// middle of an expression tree.
let Uses = [VALUE_STACK], Defs = [VALUE_STACK] in {
def BLOCK     : I<(outs), (ins Signature:$sig), [], "block   \t$sig", 0x02>;
def LOOP      : I<(outs), (ins Signature:$sig), [], "loop    \t$sig", 0x03>;

// END_BLOCK, END_LOOP, and END_FUNCTION are represented with the same opcode in
// wasm.
def END_BLOCK : I<(outs), (ins), [], "end_block", 0x0b>;
def END_LOOP  : I<(outs), (ins), [], "end_loop", 0x0b>;
let isTerminator = 1, isBarrier = 1 in
def END_FUNCTION : I<(outs), (ins), [], "end_function", 0x0b>;
} // Uses = [VALUE_STACK], Defs = [VALUE_STACK]

multiclass RETURN<WebAssemblyRegClass vt> {
  def RETURN_#vt : I<(outs), (ins vt:$val), [(WebAssemblyreturn vt:$val)],
                     "return  \t$val", 0x0f>;
  // Equivalent to RETURN_#vt, for use at the end of a function when wasm
  // semantics return by falling off the end of the block.
  let isCodeGenOnly = 1 in
  def FALLTHROUGH_RETURN_#vt : I<(outs), (ins vt:$val), []>;
}

multiclass SIMD_RETURN<ValueType vt> {
  def RETURN_#vt : SIMD_I<(outs), (ins V128:$val),
                          [(WebAssemblyreturn (vt V128:$val))],
                          "return  \t$val", 0x0f>;
  // Equivalent to RETURN_#vt, for use at the end of a function when wasm
  // semantics return by falling off the end of the block.
  let isCodeGenOnly = 1 in
  def FALLTHROUGH_RETURN_#vt : SIMD_I<(outs), (ins V128:$val), []>;
}

let isTerminator = 1, hasCtrlDep = 1, isBarrier = 1 in {

let isReturn = 1 in {
  defm "": RETURN<I32>;
  defm "": RETURN<I64>;
  defm "": RETURN<F32>;
  defm "": RETURN<F64>;
  defm "": RETURN<EXCEPT_REF>;
  defm "": SIMD_RETURN<v16i8>;
  defm "": SIMD_RETURN<v8i16>;
  defm "": SIMD_RETURN<v4i32>;
  defm "": SIMD_RETURN<v4f32>;

  def RETURN_VOID : I<(outs), (ins), [(WebAssemblyreturn)], "return", 0x0f>;

  // This is to RETURN_VOID what FALLTHROUGH_RETURN_#vt is to RETURN_#vt.
  let isCodeGenOnly = 1 in
  def FALLTHROUGH_RETURN_VOID : I<(outs), (ins), []>;
} // isReturn = 1

def UNREACHABLE : I<(outs), (ins), [(trap)], "unreachable", 0x00>;
} // isTerminator = 1, hasCtrlDep = 1, isBarrier = 1

//===----------------------------------------------------------------------===//
// Exception handling instructions
//===----------------------------------------------------------------------===//

// Throwing an exception: throw / rethrow
let isTerminator = 1, hasCtrlDep = 1, isBarrier = 1 in {
def THROW_I32 : I<(outs), (ins i32imm:$tag, I32:$val),
                  [(int_wasm_throw imm:$tag, I32:$val)], "throw   \t$tag, $val",
                  0x08>;
def THROW_I64 : I<(outs), (ins i32imm:$tag, I64:$val),
                  [(int_wasm_throw imm:$tag, I64:$val)], "throw   \t$tag, $val",
                  0x08>;
def RETHROW : I<(outs), (ins i32imm:$rel_depth), [], "rethrow \t$rel_depth",
                0x09>;
} // isTerminator = 1, hasCtrlDep = 1, isBarrier = 1

// Region within which an exception is caught: try / end_try
let Uses = [VALUE_STACK], Defs = [VALUE_STACK] in {
def TRY     : I<(outs), (ins Signature:$sig), [], "try     \t$sig", 0x06>;
def END_TRY : I<(outs), (ins), [], "end_try", 0x0b>;
} // Uses = [VALUE_STACK], Defs = [VALUE_STACK]

// Catching an exception: catch / catch_all
let hasCtrlDep = 1 in {
def CATCH_I32 : I<(outs I32:$dst), (ins i32imm:$tag),
                  [(set I32:$dst, (int_wasm_catch imm:$tag))],
                  "i32.catch   \t$dst, $tag", 0x07>;
def CATCH_I64 : I<(outs I64:$dst), (ins i32imm:$tag),
                  [(set I64:$dst, (int_wasm_catch imm:$tag))],
                  "i64.catch   \t$dst, $tag", 0x07>;
def CATCH_ALL : I<(outs), (ins), [], "catch_all", 0x05>;
}

// Pseudo instructions: cleanupret / catchret
// They are not return instructions in wasm, but setting 'isReturn' to true as
// in X86 is necessary for computing EH scope membership.
let isTerminator = 1, hasSideEffects = 1, isBarrier = 1, hasCtrlDep = 1,
    isCodeGenOnly = 1, isReturn = 1 in {
  def CLEANUPRET : I<(outs), (ins), [(cleanupret)], "", 0>;
  def CATCHRET : I<(outs), (ins bb_op:$dst, bb_op:$from),
                   [(catchret bb:$dst, bb:$from)], "", 0>;
}

} // Defs = [ARGUMENTS]
