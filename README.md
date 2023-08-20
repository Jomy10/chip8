# CHIP8

Chip8 emulator written in Zig. It is written so that the renderer (= platform) can be easily switched out.

## Platforms

These are the currently supported platforms and the platforms that are planned:

- [x] [Terminal](docs/internal/terminal.md) (in rework)
- [x] [SDL](docs/internal/sdl.md)
- [ ] Metal
- [ ] OpenGL
- [ ] WebGPU
- [ ] WebGL
- [ ] HTMLCanvas (WIP)

## Building

e.g.

```bash
zig build -Dexe-type=cli -Dplatform=terminal
```

Options:
- **exe-type**: cli | launcher
- **platform**: terminal | sdl | testPlatform

## Running

### CLI

Using the files from the build phase:

```bash
./chip8 <ROM> <Scale> <Delay>
```

- **ROM**: the rom file to play
- **Scale**: the scale of the window (when *s* is scale, then the window will be 64\**s* x 32\**s*)
- **Delay**: number in Hz indicating the clockspeed (e.g. 60)

### Launcher

TODO

## Development

### Adding a new platform

## Roadmap

- Add more platforms
- Migrate to Zig v11 once it is avaiable on Homebrew

## License

Licensed under the LGPLv3
