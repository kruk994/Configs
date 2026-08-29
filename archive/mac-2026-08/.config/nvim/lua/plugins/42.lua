-- ══════════════════════════════════════════════════════════════════════════
--  Norminette + sprawdzanie skladni w Neovimie.
--
--  DLACZEGO NVIM SIE WYWRACAL — zmierzone, nie zgadniete:
--  norminette 3.3.59 WISI W NIESKONCZONOSC na wywolaniu funkcji bez srednika.
--  Zawezone do konkretu:
--
--      f()      w if{} / while{} / for{} / na koncu funkcji   -> ZAWIESZA
--      f();     to samo ze srednikiem                          -> 116 ms, ok
--      a = 1    przypisanie bez srednika                       -> 141 ms, ok
--
--  Upstreamowy plugin czekal na nia SYNCHRONICZNIE (`io.popen`), wiec razem
--  z nia zamierzal caly edytor. Pierwsza wersja tego pliku uzywala
--  `vim.fn.systemlist` — tez synchronicznie, wiec objaw byl identyczny.
--  Dlatego powrot do poprzedniej wersji nic by nie dal: problem nie jest
--  w limicie bledow, tylko w czekaniu na zawieszony proces.
--
--  Teraz wszystko chodzi asynchronicznie (`jobstart`) z twardym timeoutem.
--  Proces jest zabijany po 3 s, a Ty dostajesz konkretna podpowiedz zamiast
--  zamrozonego nvima.
--
--  DRUGA RZECZ: norminette to checker STYLU, nie skladni — nigdy nie powie
--  „brakuje srednika". Dlatego doszedl drugi silnik: `cc -fsyntax-only`,
--  ktory mowi wprost `expected ';' before '}' token` i podaje linie.
--  Bledy skladni sa sortowane na gore listy, bo to one sa przyczyna reszty.
--
--  Plugin `norminette42.nvim` zostaje wylaczony — mial trzy osobne wady:
--  martwe `maxErrorsToShow`, diagnostyki z `message == nil`, i autocmd na
--  `BufEnter`, ktory odpalal go przy kazdym przejsciu miedzy oknami.
--
--  Komendy: :Norm  :NormOn  :NormOff  :NormLimit <n>  :NormSyntax  :NormDebug
-- ══════════════════════════════════════════════════════════════════════════

require("config.norm42").setup({
  limit = 5,      -- ile diagnostyk na zrodlo
  timeout = 3000, -- ms; norminette normalnie konczy w ~150 ms
  syntax = true,  -- drugi silnik: cc -fsyntax-only
})

return {
  { "hardyrafael17/norminette42.nvim", enabled = false },
}
