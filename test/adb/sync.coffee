Fs = require 'fs'
Stream = require 'stream'
Async = require 'async'
{expect, assert} = require 'chai'

Adb = require '../../'
Sync = require '../../src/adb/sync'

# This test suite is a bit special in that it requires a connected Android
# device (or many devices). All will be tested.
describe 'Sync', ->

  SURELY_EXISTING_FILE = '/system/build.prop'
  SURELY_EXISTING_PATH = '/'
  SURELY_NONEXISTING_PATH = '/non-existing-path'
  SURELY_WRITABLE_FILE = '/data/local/tmp/_sync.test'

  client = null
  deviceList = null

  forEachSyncDevice = (iterator, done) ->
    assert deviceList.length > 0,
      'At least one connected Android device is required'
    Async.each deviceList, (device, callback) ->
      client.syncService device.id, (err, sync) ->
        expect(err).to.be.null
        expect(sync).to.be.an.instanceof Sync
        iterator sync, callback
    , done

  before (done) ->
    client = Adb.createClient()
    client.listDevices (err, devices) ->
      deviceList = devices
      done err

  describe 'end()', ->

    it "should end the sync connection", (done) ->
      forEachSyncDevice (sync, callback) ->
        sync.connection.on 'end', ->
          done()
        sync.end()
      , done

  describe 'pullFileStream(path, callback)', ->

    it "should retrieve the same content pushFileStream() pushed", (done) ->
      forEachSyncDevice (sync, callback) ->
        stream = new Stream.PassThrough
        content = 'ABCDEFGHI'
        sync.pushFileStream SURELY_WRITABLE_FILE, stream, (err) ->
          expect(err).to.be.null
          sync.pullFileStream SURELY_WRITABLE_FILE, (err, out) ->
            expect(err).to.be.null
            out.on 'readable', ->
              expect(out.read().toString()).to.equal content
              callback()
        stream.write content
        stream.end()
      , done

    it "should return the Sync instance for chaining", (done) ->
      forEachSyncDevice (sync, callback) ->
        rval = sync.pullFileStream SURELY_EXISTING_FILE, ->
        expect(rval).to.be.an.instanceof Sync
        callback()
      , done

  describe 'stat(path, callback)', ->

    it "should return an ENOENT error if the path does not exist", (done) ->
      forEachSyncDevice (sync, callback) ->
        sync.stat SURELY_NONEXISTING_PATH, (err, stats) ->
          expect(err).to.be.an.instanceof Error
          expect(err.code).to.equal 'ENOENT'
          expect(err.errno).to.equal 34
          expect(err.path).to.equal
          expect(stats).to.be.undefined
          callback()
      , done

    it "should return an fs.Stats instance for an existing path", (done) ->
      forEachSyncDevice (sync, callback) ->
        sync.stat SURELY_EXISTING_PATH, (err, stats) ->
          expect(err).to.be.null
          expect(stats).to.be.an.instanceof Fs.Stats
          callback()
      , done

    describe 'Stats', ->

      it "should set the `.mode` property for isFile() etc", (done) ->
        forEachSyncDevice (sync, callback) ->
          sync.stat SURELY_EXISTING_FILE, (err, stats) ->
            expect(err).to.be.null
            expect(stats).to.be.an.instanceof Fs.Stats
            expect(stats.mode).to.be.above 0
            expect(stats.isFile()).to.be.true
            expect(stats.isDirectory()).to.be.false
            callback()
        , done

      it "should set the `.size` property", (done) ->
        forEachSyncDevice (sync, callback) ->
          sync.stat SURELY_EXISTING_FILE, (err, stats) ->
            expect(err).to.be.null
            expect(stats).to.be.an.instanceof Fs.Stats
            expect(stats.isFile()).to.be.true
            expect(stats.size).to.be.above 0
            callback()
        , done

      it "should set the `.mtime` property", (done) ->
        forEachSyncDevice (sync, callback) ->
          sync.stat SURELY_EXISTING_FILE, (err, stats) ->
            expect(err).to.be.null
            expect(stats).to.be.an.instanceof Fs.Stats
            expect(stats.mtime).to.be.an.instanceof Date
            callback()
        , done

