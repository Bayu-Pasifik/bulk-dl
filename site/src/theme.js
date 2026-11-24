import {
  argbFromHex,
  themeFromSourceColor,
  applyTheme,
} from '@material/material-color-utilities';

export const SEEDS = [
  { name: 'Green', hex: '#2E7D32' },
  { name: 'Blue', hex: '#1E6FD9' },
  { name: 'Purple', hex: '#7B4FD6' },
  { name: 'Pink', hex: '#D6457E' },
  { name: 'Orange', hex: '#E0701B' },
  { name: 'Teal', hex: '#00897B' },
];

/** Generates a Material 3 scheme from the seed and sets --md-sys-color-* vars. */
export function applySeed(hex, dark) {
  const theme = themeFromSourceColor(argbFromHex(hex));
  applyTheme(theme, { target: document.documentElement, dark });
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
}
