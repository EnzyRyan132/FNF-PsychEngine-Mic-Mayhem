package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.StageData;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	private static var curWeek:Int = 0;

	var txtWeekTitle:FlxText;
	var txtTracklist:FlxText;

	var weekPreview:FlxSprite;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;

	var difficultyUp:FlxText;
	var difficultyDown:FlxText;

	var weekLeft:FlxText;
	var weekRight:FlxText;

	var tracksSprite:FlxSprite;

	var loadedWeeks:Array<WeekData> = [];

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;

		WeekData.reloadWeekFiles(true);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;

			MusicBeatState.switchState(
				new states.ErrorState(
					"NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
					function()
						MusicBeatState.switchState(new states.editors.WeekEditorState()),
					function()
						MusicBeatState.switchState(new states.MainMenuState())
				)
			);

			return;
		}

		// ============================================================
		// CARREGA AS WEEKS
		// ============================================================

		loadedWeeks = [];

		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);

			if (!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
			}
		}

		if (loadedWeeks.length <= 0)
		{
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new states.MainMenuState());
			return;
		}

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;

		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		// ============================================================
		// FUNDO
		// ============================================================

		var bg:FlxSprite = new FlxSprite().makeGraphic(
			FlxG.width,
			FlxG.height,
			FlxColor.WHITE
		);

		add(bg);

		// ============================================================
		// PREVIEW DA WEEK
		// ============================================================

		weekPreview = new FlxSprite();
		weekPreview.antialiasing = ClientPrefs.data.antialiasing;
		add(weekPreview);

		// ============================================================
		// SCORE
		// ============================================================

		scoreText = new FlxText(
			0,
			25,
			FlxG.width - 35,
			"",
			32
		);

		scoreText.setFormat(
			Paths.font("vcr.ttf"),
			32,
			FlxColor.BLACK,
			RIGHT
		);

		add(scoreText);

		// ============================================================
		// TRACKS
		// ============================================================

		tracksSprite = new FlxSprite(
			FlxG.width - 320,
			105
		).loadGraphic(Paths.image('Menu_Tracks'));

		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;

		add(tracksSprite);

		txtTracklist = new FlxText(
			FlxG.width - 300,
			150,
			260,
			"",
			24
		);

		txtTracklist.setFormat(
			Paths.font("vcr.ttf"),
			24,
			FlxColor.BLACK,
			CENTER
		);

		add(txtTracklist);

		// ============================================================
		// DIFICULDADE
		// ============================================================

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		difficultyUp = new FlxText(
			35,
			25,
			100,
			"↑",
			45
		);

		difficultyUp.setFormat(
			Paths.font("vcr.ttf"),
			45,
			FlxColor.BLACK,
			CENTER
		);

		difficultySelectors.add(difficultyUp);

		sprDifficulty = new FlxSprite();
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;

		difficultySelectors.add(sprDifficulty);

		difficultyDown = new FlxText(
			35,
			155,
			100,
			"↓",
			45
		);

		difficultyDown.setFormat(
			Paths.font("vcr.ttf"),
			45,
			FlxColor.BLACK,
			CENTER
		);

		difficultySelectors.add(difficultyDown);

		// ============================================================
		// SETAS DA WEEK
		// ============================================================

		weekLeft = new FlxText(
			80,
			FlxG.height - 115,
			100,
			"<",
			75
		);

		weekLeft.setFormat(
			Paths.font("vcr.ttf"),
			75,
			FlxColor.BLACK,
			CENTER
		);

		add(weekLeft);

		weekRight = new FlxText(
			FlxG.width - 180,
			FlxG.height - 115,
			100,
			">",
			75
		);

		weekRight.setFormat(
			Paths.font("vcr.ttf"),
			75,
			FlxColor.BLACK,
			CENTER
		);

		add(weekRight);

		// ============================================================
		// NOME DA WEEK
		// ============================================================

		txtWeekTitle = new FlxText(
			150,
			FlxG.height - 105,
			FlxG.width - 300,
			"",
			45
		);

		txtWeekTitle.setFormat(
			Paths.font("vcr.ttf"),
			45,
			FlxColor.BLACK,
			CENTER
		);

		add(txtWeekTitle);

		// ============================================================
		// DIFICULDADE
		// ============================================================

		Difficulty.resetList();

		if (lastDifficultyName == '')
			lastDifficultyName = Difficulty.getDefault();

		curDifficulty = Math.round(
			Math.max(
				0,
				Difficulty.defaultList.indexOf(lastDifficultyName)
			)
		);

		changeWeek();
		changeDifficulty();

		super.create();
	}

	override function closeSubState()
	{
		persistentUpdate = true;

		changeWeek();
		changeDifficulty();

		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if (WeekData.weeksList.length < 1)
		{
			if (controls.BACK && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));

				movedBack = true;

				MusicBeatState.switchState(new MainMenuState());
			}

			super.update(elapsed);
			return;
		}

		// ============================================================
		// SCORE
		// ============================================================

		if (intendedScore != lerpScore)
		{
			lerpScore = Math.floor(
				FlxMath.lerp(
					intendedScore,
					lerpScore,
					Math.exp(-elapsed * 30)
				)
			);

			if (Math.abs(intendedScore - lerpScore) < 10)
				lerpScore = intendedScore;

			updateScoreText();
		}

		if (!movedBack && !selectedWeek)
		{
			// ========================================================
			// WEEK: ESQUERDA / DIREITA
			// ========================================================

			if (controls.UI_LEFT_P)
			{
				changeWeek(-1);

				FlxG.sound.play(
					Paths.sound('scrollMenu')
				);
			}

			if (controls.UI_RIGHT_P)
			{
				changeWeek(1);

				FlxG.sound.play(
					Paths.sound('scrollMenu')
				);
			}

			// ========================================================
			// DIFICULDADE: CIMA / BAIXO
			// ========================================================

			if (controls.UI_UP_P)
			{
				changeDifficulty(-1);

				FlxG.sound.play(
					Paths.sound('scrollMenu')
				);
			}

			if (controls.UI_DOWN_P)
			{
				changeDifficulty(1);

				FlxG.sound.play(
					Paths.sound('scrollMenu')
				);
			}

			// ========================================================
			// GAMEPLAY CHANGERS
			// ========================================================

			if (FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;

				openSubState(
					new GameplayChangersSubstate()
				);
			}
			else if (controls.RESET)
			{
				persistentUpdate = false;

				openSubState(
					new ResetScoreSubState(
						'',
						curDifficulty,
						'',
						curWeek
					)
				);
			}
			else if (controls.ACCEPT)
			{
				selectWeek();
			}
		}

		// ============================================================
		// VOLTAR
		// ============================================================

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(
				Paths.sound('cancelMenu')
			);

			movedBack = true;

			MusicBeatState.switchState(
				new MainMenuState()
			);
		}

		// ============================================================
		// EFEITO DAS SETAS
		// ============================================================

		if (controls.UI_LEFT)
			weekLeft.alpha = 1;
		else
			weekLeft.alpha = 0.65;

		if (controls.UI_RIGHT)
			weekRight.alpha = 1;
		else
			weekRight.alpha = 0.65;

		if (controls.UI_UP)
			difficultyUp.alpha = 1;
		else
			difficultyUp.alpha = 0.65;

		if (controls.UI_DOWN)
			difficultyDown.alpha = 1;
		else
			difficultyDown.alpha = 0.65;

		super.update(elapsed);
	}

	// ================================================================
	// SELECIONAR WEEK
	// ================================================================

	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			var songArray:Array<String> = [];

			var leWeek:Array<Dynamic> =
				loadedWeeks[curWeek].songs;

			for (i in 0...leWeek.length)
			{
				songArray.push(leWeek[i][0]);
			}

			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;

				selectedWeek = true;

				var diffic =
					Difficulty.getFilePath(curDifficulty);

				if (diffic == null)
					diffic = '';

				PlayState.storyDifficulty = curDifficulty;

				Song.loadFromJson(
					PlayState.storyPlaylist[0].toLowerCase() + diffic,
					PlayState.storyPlaylist[0].toLowerCase()
				);

				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}
			catch (e:Dynamic)
			{
				trace('ERROR! $e');
				return;
			}

			if (!stopspamming)
			{
				FlxG.sound.play(
					Paths.sound('confirmMenu')
				);

				stopspamming = true;
			}

			var directory =
				StageData.forceNextDirectory;

			LoadingState.loadNextDirectory();

			StageData.forceNextDirectory =
				directory;

			@:privateAccess
			if (
				PlayState._lastLoadedModDirectory
				!= Mods.currentModDirectory
			)
			{
				trace(
					'CHANGED MOD DIRECTORY, RELOADING STUFF'
				);

				Paths.freeGraphicsFromMemory();
			}

			LoadingState.prepareToSong();

			new FlxTimer().start(
				1,
				function(tmr:FlxTimer)
				{
					#if !SHOW_LOADING_SCREEN
					FlxG.sound.music.stop();
					#end

					LoadingState.loadAndSwitchState(
						new PlayState(),
						true
					);

					FreeplayState.destroyFreeplayVocals();
				}
			);

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else
		{
			FlxG.sound.play(
				Paths.sound('cancelMenu')
			);
		}
	}

	// ================================================================
	// DIFICULDADE
	// ================================================================

	function changeDifficulty(change:Int = 0):Void
	{
		if (Difficulty.list.length <= 0)
			return;

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length - 1;

		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(
			loadedWeeks[curWeek]
		);

		var diff:String =
			Difficulty.getString(
				curDifficulty,
				false
			);

		var newImage:FlxGraphic =
			Paths.image(
				'menudifficulties/' +
				Paths.formatToSongPath(diff)
			);

		if (sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);

			sprDifficulty.x =
				85 - sprDifficulty.width / 2;

			sprDifficulty.y =
				90 - sprDifficulty.height / 2;

			sprDifficulty.alpha = 0;

			FlxTween.cancelTweensOf(
				sprDifficulty
			);

			FlxTween.tween(
				sprDifficulty,
				{
					alpha: 1,
					y: sprDifficulty.y + 8
				},
				0.1
			);
		}

		lastDifficultyName = diff;

		#if !switch
		intendedScore =
			Highscore.getWeekScore(
				loadedWeeks[curWeek].fileName,
				curDifficulty
			);
		#end

		updateScoreText();
	}

	// ================================================================
	// WEEK
	// ================================================================

	function changeWeek(change:Int = 0):Void
	{
		if (loadedWeeks.length <= 0)
			return;

		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;

		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData =
			loadedWeeks[curWeek];

		WeekData.setDirectoryFromWeek(
			leWeek
		);

		// ============================================================
		// NOME
		// ============================================================

		var leName:String =
			Language.getPhrase(
				'storyname_' + leWeek.fileName,
				leWeek.storyName
			);

		txtWeekTitle.text =
			leName.toUpperCase();

		txtWeekTitle.screenCenter(X);

		// ============================================================
		// PREVIEW
		// ============================================================

		weekPreview.visible = false;

		var assetName:String =
			leWeek.weekBackground;

		if (
			assetName != null &&
			assetName.length > 0
		)
		{
			try
			{
				weekPreview.loadGraphic(
					Paths.image(
						'menubackgrounds/menu_' +
						assetName
					)
				);

				weekPreview.visible = true;

				// Tamanho máximo do preview
				var maxWidth:Float = FlxG.width * 0.55;
				var maxHeight:Float = FlxG.height * 0.55;

				var scale:Float = Math.min(
					maxWidth / weekPreview.width,
					maxHeight / weekPreview.height
				);

				weekPreview.scale.set(
					scale,
					scale
				);

				weekPreview.updateHitbox();

				weekPreview.x =
					(FlxG.width - weekPreview.width) / 2;

				weekPreview.y =
					(FlxG.height - weekPreview.height) / 2 - 20;
			}
			catch (e:Dynamic)
			{
				trace(
					'Could not load week preview: ' +
					e
				);

				weekPreview.visible = false;
			}
		}

		// ============================================================
		// DIFICULDADE DISPONÍVEL
		// ============================================================

		Difficulty.loadFromWeek();

		var unlocked:Bool =
			!weekIsLocked(
				leWeek.fileName
			);

		difficultySelectors.visible =
			unlocked;

		if (
			Difficulty.list.contains(
				Difficulty.getDefault()
			)
		)
		{
			curDifficulty =
				Math.round(
					Math.max(
						0,
						Difficulty.defaultList.indexOf(
							Difficulty.getDefault()
						)
					)
				);
		}
		else
		{
			curDifficulty = 0;
		}

		var newPos:Int =
			Difficulty.list.indexOf(
				lastDifficultyName
			);

		if (newPos > -1)
			curDifficulty = newPos;

		updateText();
		changeDifficulty();
	}

	// ================================================================
	// TEXTO / TRACKS
	// ================================================================

	function updateText()
	{
		var leWeek:WeekData =
			loadedWeeks[curWeek];

		txtTracklist.text = '';

		for (i in 0...leWeek.songs.length)
		{
			var songName:String =
				leWeek.songs[i][0];

			txtTracklist.text +=
				songName.toUpperCase();

			if (i < leWeek.songs.length - 1)
				txtTracklist.text += '\n';
		}

		txtTracklist.y =
			tracksSprite.y + 55;

		txtTracklist.x =
			tracksSprite.x + 25;

		txtTracklist.fieldWidth =
			tracksSprite.width - 50;

		#if !switch
		intendedScore =
			Highscore.getWeekScore(
				leWeek.fileName,
				curDifficulty
			);
		#end

		updateScoreText();
	}

	// ================================================================
	// SCORE
	// ================================================================

	function updateScoreText()
	{
		scoreText.text =
			Language.getPhrase(
				'week_score',
				'WEEK SCORE: {1}',
				[lerpScore]
			);

		scoreText.x = 0;
		scoreText.width = FlxG.width - 35;
	}

	// ================================================================
	// LOCK
	// ================================================================

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData =
			WeekData.weeksLoaded.get(name);

		return (
			!leWeek.startUnlocked &&
			leWeek.weekBefore.length > 0 &&
			(
				!weekCompleted.exists(
					leWeek.weekBefore
				)
				||
				!weekCompleted.get(
					leWeek.weekBefore
				)
			)
		);
	}
}
