package main

import "core:fmt"
import "core:math"
import "core:strings"
import b2d "vendor:box2d"
import rl "vendor:raylib"

LENGTH_UNIT :: 64.0
W_HEIGHT :: 700
W_WIDTH :: 1000

Block :: struct {
	shape_id: b2d.ShapeId,
	body_id:  b2d.BodyId,
}

global_blocks: [dynamic]Block
BOX_DIMENSIONS :: b2d.Vec2{64, 64}

create_block :: proc(world: ^b2d.WorldId) {
	if !rl.IsMouseButtonReleased(.RIGHT) {
		return
	}

	pos := rl.GetMousePosition()

	box_def := b2d.DefaultBodyDef()
	box_def.type = .dynamicBody
	box_def.position = pos

	box_shape_def := b2d.DefaultShapeDef()
	box_shape_def.restitution = 0.5

	box := b2d.CreateBody(world^, box_def)

	polygon := b2d.MakeBox(BOX_DIMENSIONS.x, BOX_DIMENSIONS.y)
	box_shape_id := b2d.CreatePolygonShape(box, box_shape_def, polygon)
	append(&global_blocks, Block{body_id = box, shape_id = box_shape_id})
}

destroy_blocks :: proc() {
	for block in global_blocks {
		b2d.DestroyShape(block.shape_id)
		b2d.DestroyBody(block.body_id)
	}
	clear_dynamic_array(&global_blocks)
}

draw_blocks :: proc() {
	to_remove: [dynamic]int
	should_draw := false
	at := rl.Vector2(0)
	defer delete(to_remove)
	for block, i in global_blocks {
		p := b2d.Body_GetWorldPoint(block.body_id, {0, 0})
		rec := rl.Rectangle {
			height = BOX_DIMENSIONS.x * 2,
			width  = BOX_DIMENSIONS.y * 2,
			x      = p.x,
			y      = p.y,
		}
		mouse_at := rl.GetMousePosition() + BOX_DIMENSIONS
		color := rl.PINK
		if rl.CheckCollisionPointRec(mouse_at, rec) {
			shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
			if shift {
				color = rl.RED
				at = {f32(rec.x - BOX_DIMENSIONS.x * 0.5), f32(rec.y - BOX_DIMENSIONS.y * 2)}
				should_draw = true
			}
			if rl.IsMouseButtonDown(.LEFT) && shift {
				append(&to_remove, i)
			}
		}
		rot := b2d.Rot_GetAngle(b2d.Body_GetRotation(block.body_id))
		rl.DrawRectanglePro(rec, BOX_DIMENSIONS, rl.RAD2DEG * rot, color)
	}

	if should_draw {
		rl.DrawText("Delete?", i32(at.x), i32(at.y), 30, rl.RED)
	}

	#reverse for idx in to_remove {
		b := global_blocks[idx]
		b2d.DestroyShape(b.shape_id)
		b2d.DestroyBody(b.body_id)
		ordered_remove(&global_blocks, idx)
	}
}

main :: proc() {
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(W_WIDTH, W_HEIGHT, "drop")
	rl.SetTargetFPS(60)
	b2d.SetLengthUnitsPerMeter(LENGTH_UNIT)

	worldDef := b2d.DefaultWorldDef()
	worldDef.gravity = {0, 9.8 * LENGTH_UNIT}

	world := b2d.CreateWorld(worldDef)
	defer b2d.DestroyWorld(world)

	box_def := b2d.DefaultBodyDef()
	box_def.type = .dynamicBody
	box_def.position = {138, 138}
	box_def.rotation = b2d.MakeRot(1)

	box_shape_def := b2d.DefaultShapeDef()
	box_shape_def.restitution = 0.5

	box := b2d.CreateBody(world, box_def)

	defer b2d.DestroyBody(box)
	polygon := b2d.MakeBox(BOX_DIMENSIONS.x, BOX_DIMENSIONS.y)
	box_shape_id := b2d.CreatePolygonShape(box, box_shape_def, polygon)
	defer b2d.DestroyShape(box_shape_id)

	ground_def := b2d.DefaultBodyDef()
	ground_def.type = .staticBody
	ground_def.position = {0, 675}
	ground_id := b2d.CreateBody(world, ground_def)
	ground_dimension := b2d.Vec2{2000, 25}
	ground_shape := b2d.CreatePolygonShape(
		ground_id,
		b2d.DefaultShapeDef(),
		b2d.MakeBox(ground_dimension.x, ground_dimension.y),
	)
	defer b2d.DestroyBody(ground_id)
	defer b2d.DestroyShape(ground_shape)

	b2d.Body_SetAngularVelocity(box, -10)
	b2d.Body_SetLinearVelocity(box, -5)

	initial_down := rl.Vector2{0, 0}
	mouse_down := false
	pause := false
	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		if !pause {
			if mouse_down {
				b2d.World_Step(world, dt / 3, 4)
			} else {
				b2d.World_Step(world, dt, 8)
			}
		}
		rl.BeginDrawing()

		rl.ClearBackground(rl.BEIGE)

		create_block(&world)
		draw_blocks()

		{
			p := b2d.Body_GetWorldPoint(box, {0, 0})
			rec := rl.Rectangle {
				height = BOX_DIMENSIONS.x * 2,
				width  = BOX_DIMENSIONS.y * 2,
				x      = p.x,
				y      = p.y,
			}
			rot := b2d.Rot_GetAngle(b2d.Body_GetRotation(box))
			color := rl.BLUE
			mouse_at := rl.GetMousePosition() + BOX_DIMENSIONS
			if rl.CheckCollisionPointRec(mouse_at, rec) {
				if rl.IsMouseButtonDown(.LEFT) && !mouse_down {
					initial_down = mouse_at
					mouse_down = true
				}
				color = rl.GREEN
			}
			if mouse_down {
				color = rl.DARKGREEN
				rl.DrawLineEx(initial_down, mouse_at, 3.0, rl.LIME)
			}
			rl.DrawRectanglePro(rec, BOX_DIMENSIONS, rl.RAD2DEG * rot, color)

			if !rl.IsMouseButtonDown(.LEFT) && mouse_down {
				mouse_down = false
				mouse_now := rl.GetMousePosition() + BOX_DIMENSIONS
				diff_y := (initial_down.y - mouse_now.y) * 2

				b2d.Body_SetLinearVelocity(
					box,
					{initial_down.x - mouse_now.x, diff_y} + b2d.Body_GetLinearVelocity(box),
				)

				initial_down = {0, 0}
			}
			if pause {
				rec.x += BOX_DIMENSIONS.x
				rec.y += BOX_DIMENSIONS.y
				v := b2d.Body_GetLinearVelocity(box)

				rl.DrawText(
					fmt.caprintf("y: %f m/s\n\nx: %f m/s", v.y, v.x),
					i32(rec.x - BOX_DIMENSIONS.x * 3),
					i32(rec.y - BOX_DIMENSIONS.y * 3),
					30,
					rl.GOLD,
				)
			}
		}

		{
			p := b2d.Body_GetWorldPoint(ground_id, {0, 0})
			rec := rl.Rectangle {
				height = ground_dimension.y * 2,
				width  = ground_dimension.x * 2,
				x      = p.x,
				y      = p.y,
			}
			// fmt.printfln("x: %f y: %f", p.x, p.y)
			rot := b2d.Rot_GetAngle(b2d.Body_GetRotation(ground_id))
			rl.DrawRectanglePro(rec, ground_dimension, rl.RAD2DEG * rot, rl.BLACK)
		}

		if rl.IsKeyPressed(.R) {
			b2d.Body_SetTransform(box, {138, 138}, b2d.MakeRot(0))
			b2d.Body_SetLinearVelocity(box, b2d.Vec2_zero)
			b2d.Body_SetAngularVelocity(box, 0)
			destroy_blocks()
		}

		if rl.IsKeyPressed(.P) {
			pause = !pause
		}

		if pause {
			rl.DrawText("paused", 10, 0, 50, rl.DARKGREEN)
		}

		rl.EndDrawing()
	}
}
