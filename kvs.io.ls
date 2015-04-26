#!env kvs.io.lsc
require! {
  path
  fs
}

main = path.join path.dirname(fs.realpathSync __filename), 'lib', 'api.ls'

require main .standalone!

