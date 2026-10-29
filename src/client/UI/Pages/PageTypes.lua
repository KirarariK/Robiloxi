--!strict
-- Contrat commun des pages du menu principal.
export type Ctx = {
	open: (pageId: string, sub: string?) -> (),
	close: () -> (),
	profile: () -> { [string]: any }?,
}

export type Page = {
	Id: string,
	Title: string,
	Icon: string,
	Root: Frame,
	onShow: ((sub: string?) -> ())?,
	onHide: (() -> ())?,
	onProfile: ((profile: { [string]: any }) -> ())?,
}

return {}
