//===- GenerateVerilog.cpp - Generate Verilog source code from Loong ------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements Loong -> Verilog source-to-source transform pass power
// by Loongson.
//
// The Verilog resource is available from http://www.verilog.com/
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SCCIterator.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/InstIterator.h"

using namespace llvm;

struct GenerateVerilog : public ModulePass {
  static char ID;

  GenerateVerilog() : ModulePass(ID) {}

  bool runOnModule(Module &M);

  virtual void getAnalysisUsage(AnalysisUsage &AU) const {
    AU.setPreservesAll();
    AU.addRequired<CallGraphWrapperPass>();
  }
};

char GenerateVerilog::ID = 0;
static RegisterPass<GenerateVerilog> X("generate-verilog",
                                       "Generate Verilog source code");

bool GenerateVerilog::runOnModule(Module &M) {
  CallGraph &CG = getAnalysis<CallGraphWrapperPass>().getCallGraph();
  for (scc_iterator<CallGraph *> sccIb = scc_begin(&CG); !sccIb.isAtEnd();
       ++sccIb) {
    const std::vector<CallGraphNode *> &nextSCC = *sccIb;
    for (std::vector<CallGraphNode *>::const_iterator nsccI = nextSCC.begin(),
                                                      E = nextSCC.end();
         nsccI != E; ++nsccI) {
      Function *F = (*nsccI)->getFunction();
      if (F && !F->isDeclaration()) {
        errs() << "module " << F->getName() << "\n";
        for (inst_iterator instIb = inst_begin(F), instIe = inst_end(F);
             instIb != instIe; ++instIb) {
        }
        errs() << "endmodule"
               << "\n";
      }
    }
  }
  return false;
}
