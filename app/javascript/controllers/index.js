// Controllers are registered explicitly rather than auto-loaded from the
// filesystem. It is three extra lines per controller and it means you can find
// every registration by reading one file.
import { Application } from "@hotwired/stimulus"

import ClipboardController from "./clipboard_controller"
import DropdownController from "./dropdown_controller"
import AutosubmitController from "./autosubmit_controller"
import FlashController from "./flash_controller"
import ModalController from "./modal_controller"
import TabsController from "./tabs_controller"
import ToggleController from "./toggle_controller"

const application = Application.start()
application.debug = false
window.Stimulus = application

application.register("clipboard", ClipboardController)
application.register("dropdown", DropdownController)
application.register("autosubmit", AutosubmitController)
application.register("flash", FlashController)
application.register("modal", ModalController)
application.register("tabs", TabsController)
application.register("toggle", ToggleController)

export { application }
