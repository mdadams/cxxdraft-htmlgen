{-# OPTIONS_GHC -fno-warn-tabs #-}
{-# LANGUAGE LambdaCase, ViewPatterns, RecordWildCards, OverloadedStrings #-}

import Render (outputDir, SectionFileStyle(..))
import Document (Draft(..))
import Load14882 (load14882)
import Prelude hiding ((++), (.), writeFile)
import System.Directory (createDirectoryIfMissing, setCurrentDirectory, getCurrentDirectory, copyFile)
import System.Environment (getArgs)
import Control.Monad (forM_)
import qualified Control.Monad.Parallel as ParallelMonad
import Util

import Toc (writeTocFile)
import SectionPages
	( writeSectionFiles, writeFiguresFile, writeTablesFile, writeSingleSectionFile
	, writeIndexFiles, writeFootnotesFile, writeCssFile, writeXrefDeltaFiles)

data CmdLineArgs = CmdLineArgs
	{ repo :: FilePath
	, sectionFileStyle :: SectionFileStyle
	, sectionToWrite :: Maybe String }

readCmdLineArgs :: [String] -> CmdLineArgs
readCmdLineArgs = \case
	[repo, read -> sectionFileStyle, sec] -> CmdLineArgs{sectionToWrite=Just sec, ..}
	[repo, read -> sectionFileStyle] -> CmdLineArgs{sectionToWrite=Nothing,..}
	[repo] -> CmdLineArgs{sectionFileStyle=WithExtension,sectionToWrite=Nothing,..}
	_ -> error "param: path/to/repo"

main :: IO ()
main = do
	cwd <- getCurrentDirectory
	CmdLineArgs{..} <- readCmdLineArgs . getArgs

	setCurrentDirectory $ repo ++ "/source"
	draft@Draft{..} <- load14882

	setCurrentDirectory cwd
	createDirectoryIfMissing True outputDir
	copyFile "icon.png" (outputDir ++ "/icon.png")
	forM_ ["expanded.css", "colored.css", "normative-only.css"] $
		\f -> do
			copyFile f (outputDir ++ "/" ++ f)
	case sectionToWrite of
		Just abbr -> writeSingleSectionFile sectionFileStyle draft abbr
		Nothing -> do
			let acts =
				[ writeTocFile sectionFileStyle draft
				, writeCssFile
				, writeFiguresFile sectionFileStyle draft
				, writeFootnotesFile sectionFileStyle draft
				, writeTablesFile sectionFileStyle draft
				] ++
				writeXrefDeltaFiles sectionFileStyle draft ++
				writeIndexFiles sectionFileStyle draft index ++
				writeSectionFiles sectionFileStyle draft

			((), took) <- measure $ ParallelMonad.sequence_ acts
			putStrLn $ "Wrote files to " ++ outputDir ++ " in " ++ show (took * 1000) ++ "ms."
