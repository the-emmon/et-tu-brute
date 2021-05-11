# Nim port of Daniel Lemire's fast newline count `avxcount` 
#
# See https://lemire.me/blog/2017/02/14/how-fast-can-you-count-lines/ 
#     https://github.com/lemire/Code-used-on-Daniel-Lemire-s-blog/blob/master/2017/02/14/newlines.c

import memfiles

{.passc: "-march=native".}

{.pragma: imm, header:"immintrin.h".}
type m256i* {.importc: "__m256i", imm.} = object
proc mm256_add_epi8*(a: m256i; b: m256i): m256i         {.importc: "_mm256_add_epi8",      header: "immintrin.h".}
proc mm256_cmpeq_epi8*(a: m256i; b: m256i): m256i       {.importc: "_mm256_cmpeq_epi8",    header: "immintrin.h".}
proc mm256_lddqu_si256*(mem_addr: ptr m256i): m256i     {.importc: "_mm256_lddqu_si256",   header: "immintrin.h".}
proc mm256_set1_epi8*(a: char): m256i                   {.importc: "_mm256_set1_epi8",     header: "immintrin.h".}
proc mm256_setzero_si256*(): m256i                      {.importc: "_mm256_setzero_si256", header: "immintrin.h".}
proc mm256_subs_epi8*(a: m256i; b: m256i): m256i        {.importc: "_mm256_subs_epi8",     header: "immintrin.h".}
proc mm256_storeu_si256*(mem_addr: ptr m256i; a: m256i) {.importc: "_mm256_storeu_si256",  header: "immintrin.h".}

const vsize = 32 # sizeof(m256i)

proc `+=`(p: var pointer, q: int): void {.inline.} = 
  p = cast[pointer](cast[int](p) +% q)

proc avxcount(mfile: MemFile, delim='\l'): uint =
  var p: pointer = mfile.mem
  var remaining = mfile.size
  var count: uint = 0

  var vcntbuf: array[vsize, uint8]
  let delim256 = mm256_set1_epi8(delim)
  while remaining > vsize:
    let chunks = min(remaining /% vsize, 256)
    var vcnt = mm256_setzero_si256()
    for i in 0..<chunks:
      let bytes = mm256_lddqu_si256(cast[ptr m256i](p))
      let cmp = mm256_cmpeq_epi8(delim256, bytes)
      vcnt = mm256_add_epi8(vcnt, cmp)
      p += vsize
      remaining -= vsize

    vcnt = mm256_subs_epi8(mm256_setzero_si256(), vcnt)
    mm256_storeu_si256(cast[ptr m256i](addr(vcntbuf[0])), vcnt)
    for j in 0..<vsize: count += vcntbuf[j]

  while remaining > 0:
    if cast[ptr char](p)[] == delim: count += 1
    p += 1
    remaining -= 1
  count

proc fastCount*(list:string): uint =
  var f = memfiles.open(list)
  result = avxcount(f)
  f.close
  return result
