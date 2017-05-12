## Andreas Weber 2017 <andy.weber.aw@gmail.com>
## License GPLv3
## Use GNU Octave to play notes in LilyPond notation.

## missing:
## "\key g \minor" and so on
## rest/pause

more off
clear all
FS = 44100;

pkg load signal

function y = tone (f, len, FS)
  t = 0:1/FS:len;
  y = sin(2*pi*f*t);
endfunction

function [notes, shifts, lens] = lily (str)
  str = tolower (str);
  [S, E, TE, M, T, NM, SP] = regexp (str, '([a-gr])(e?s|is)?(['',])*([0-9])*(\.)?');

  last_len = 1/4;
  last_note = "c";

  # Versuch "relative c''" nachzubilden
  oct = 4;

  notes = shifts = lens = octaves = zeros (numel(T), 1);

  for k = 1:numel(T)
    tmp = T{k}

    notes(k) = tmp{1};
    has_dot = any(tmp{end} == ".")

    # Länge
    len_index = numel (tmp) - has_dot;
    if (isdigit (tmp{len_index}))
      lens(k) = 1 ./ str2num (tmp{len_index});
      has_len = 1;
      last_len = lens(k);
    else
      lens(k) = last_len;
    endif
    if (has_dot)
      lens (k) .* 1.5;
    endif

    # Versetzung
    shifts(k) = 0;
    if (numel(tmp) > 1 && ! isempty(strfind (tmp{2}, "s")))
      if (strcmp (tmp{2}, "is")) # Halbton hoch
        shifts(k) = +1/2;
      else                       # Halbton runter
        shifts(k) = -1/2;
      endif
    endif

    # Octave berechnen
    oct = 0;
    oct_index = 2 + (shifts(k) != 0)
    if (numel(tmp) >= oct_index)
      oct += numel (strfind (tmp{oct_index}, "'"));
      oct -= numel (strfind (tmp{oct_index}, ","));
    endif

    ## in oct steht nun, wie of hoch bzw. runter...

    diff_note = notes(k) - last_note

    last_note = notes(k);
    printf ("len=%i, oct=%i shift = %f, diff = %f\n", lens(k), oct, shifts(k), diff_note);

  endfor

  notes = char(notes);
endfunction

function f = note2freq (n, shift, oct = 4)

  assert (numel (n) == numel (shift) || isscalar (shift));
  assert (numel (n) == numel (oct) || isscalar (oct));

  base = 55 * 2.^(oct - 1);

  p = n(:) - "a";
  p (p>=2) -= 0.5;
  p (p>=4) -= 0.5;
  p(p <= 1) += 6;

  p += shift(:);

  f = base .* 2.^(p/6);

  # rest
  f(n(:) == "r") = 0;

endfunction


inp = (" g4 g g es8. bes'16\
         g4 es8. bes'16 g2\
         d'4 d d es8. bes16\
  \
         ges4 es8. bes'16 g2\
         g'4 g,8. g16 g'4 ges8. f16\
         e16 dis e8 r8 gis,8 cis4 bis8. b16\
  \
         bes16 a16 bes8 r8 es,8 ges4 es8. ges16\
         bes4 g8. bes16 d2\
         g4 g,8. g16 g'4 ges8. f16\
  \
         e16 dis e8 r8 gis,8 cis4 bis8. b16\
         bes16 a16 bes8 r8 es,8 ges4 es8. bes'16\
         g4 es8. bes'16 g2\
         g4 es8. bes'16 g2");

[notes, shifts, lens] = lily (inp);

f = note2freq (notes, shifts, 4);
y = [];

for k=1:rows(f)

  tmp = tone (f(k), 2 * lens(k), FS);

  #tmp = tmp .* hanning (numel (tmp))';
  tmp = tmp .* tukeywin (numel (tmp))';

  y = [y tmp];

endfor

#p = audioplayer (0.3 * y, FS);
#playblocking (p)


#################### tests

## use ## https://github.com/kts/matlab-midi.git
## as reference

if (!exist ("test.midi", "file"))
  fn = "test.ly"
  fid = fopen (fn, "w");
  fprintf (fid, "\\score{\n  \\relative c''{\n   \\key g \\minor\n");
  fprintf (fid, "%s", inp);
  fprintf (fid, "  }\n  \\midi { \\tempo 4 = 100 }\n  \\layout {}\n}");
  fclose (fid);
  system (sprintf ("lilypond %s", fn));
endif

addpath ("matlab-midi/src")
x=readmidi ("test.midi");
[notes, endtime]=midiInfo (x,0);

for i=1:size(notes,1)

  fr(i) = midi2freq(notes(i,3));
  durr(i) = notes(i,6) - notes(i,5);
  ampr(i) = notes(i,4)/127;;

end

## Vergleich
